const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

function trimText(text, maxLen = 120) {
  if (!text || typeof text !== 'string') return '';
  if (text.length <= maxLen) return text;
  return `${text.substring(0, maxLen - 1)}…`;
}

function parseDate(value) {
  if (!value) return null;
  if (value instanceof Date) return value;
  if (value && typeof value.toDate === 'function') return value.toDate(); // Firestore Timestamp
  if (typeof value === 'string') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function getStoredEstimatedMinutes(tripData) {
  const raw = tripData?.estimatedDurationMinutes;
  if (typeof raw === 'number' && Number.isFinite(raw)) return Math.max(0, Math.round(raw));
  if (typeof raw === 'string') {
    const parsed = Number.parseInt(raw, 10);
    return Number.isNaN(parsed) ? null : Math.max(0, parsed);
  }
  return null;
}

function toNumber(value) {
  if (typeof value === 'number') return Number.isFinite(value) ? value : null;
  if (typeof value === 'string') {
    const parsed = Number.parseFloat(value);
    return Number.isNaN(parsed) ? null : parsed;
  }
  return null;
}

function normalizePoint(point) {
  if (!point || typeof point !== 'object') return null;
  const lat = toNumber(point.lat);
  const lng = toNumber(point.lng);
  if (lat == null || lng == null) return null;
  return {lat, lng};
}

function haversineKm(a, b) {
  const toRad = (deg) => deg * (Math.PI / 180);
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const aa = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(aa), Math.sqrt(1 - aa));
  return 6371 * c;
}

function estimateDurationMinutesFromRoute(tripData) {
  const origin = normalizePoint(tripData?.origin);
  const destination = normalizePoint(tripData?.destination);
  if (!origin || !destination) return 0;

  const stopsRaw = Array.isArray(tripData?.stops) ? tripData.stops : [];
  const stops = stopsRaw.map((s) => normalizePoint(s)).filter(Boolean);
  const points = [origin, ...stops, destination];

  let distanceKm = 0;
  for (let i = 0; i < points.length - 1; i += 1) {
    distanceKm += haversineKm(points[i], points[i + 1]);
  }

  if (distanceKm <= 0.1) return 0;
  // Same heuristic as client UI: average 75 km/h + 15 min city buffer.
  const minutes = Math.round((distanceKm / 75) * 60 + 15);
  return Math.max(5, minutes);
}

function resolveEstimatedMinutes(tripData) {
  const stored = getStoredEstimatedMinutes(tripData);
  if (stored != null && stored > 0) return {minutes: stored, backfilled: false};
  const estimated = estimateDurationMinutesFromRoute(tripData);
  return {minutes: estimated, backfilled: estimated > 0};
}

exports.onNewMessagePush = onDocumentCreated(
  {
    document: 'messages/{messageId}',
    region: 'us-central1'
  },
  async (event) => {
    const message = event.data?.data();
    if (!message) {
      logger.warn('No message payload in Firestore trigger.', {eventId: event.id});
      return;
    }

    const senderId = message.senderId;
    const receiverId = message.receiverId;
    const messageText = trimText(message.text || '');

    if (!senderId || !receiverId) {
      logger.warn('Missing senderId/receiverId for message.', {
        messageId: event.params.messageId
      });
      return;
    }

    if (senderId === receiverId) {
      return;
    }

    const [senderSnap, receiverSnap] = await Promise.all([
      db.collection('users').doc(senderId).get(),
      db.collection('users').doc(receiverId).get()
    ]);

    if (!receiverSnap.exists) {
      logger.warn('Receiver user not found.', {receiverId});
      return;
    }

    const receiverData = receiverSnap.data() || {};
    const token = receiverData.fcmToken;

    if (!token || typeof token !== 'string') {
      logger.info('Receiver has no FCM token.', {receiverId});
      return;
    }

    const senderName = senderSnap.exists
      ? (senderSnap.data()?.name || 'Нове повідомлення')
      : 'Нове повідомлення';

    const payload = {
      token,
      notification: {
        title: senderName,
        body: messageText || 'Нове повідомлення'
      },
      data: {
        type: 'chat_message',
        senderId: String(senderId),
        receiverId: String(receiverId),
        messageId: String(event.params.messageId || ''),
        click_action: 'FLUTTER_NOTIFICATION_CLICK'
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'chat_messages',
          sound: 'default'
        }
      },
      apns: {
        headers: {
          'apns-priority': '10'
        },
        payload: {
          aps: {
            sound: 'default'
          }
        }
      }
    };

    try {
      const response = await messaging.send(payload);
      logger.info('Push sent.', {
        response,
        receiverId,
        messageId: event.params.messageId
      });
    } catch (error) {
      const code = error?.code || '';
      logger.error('FCM send failed.', {
        code,
        message: error?.message,
        receiverId,
        messageId: event.params.messageId
      });

      // Remove stale token if Firebase says token is invalid.
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token'
      ) {
        await db.collection('users').doc(receiverId).set(
          {fcmToken: admin.firestore.FieldValue.delete()},
          {merge: true}
        );
      }
    }
  }
);

// Tiny test harness: manually send a test push to your current user.
// Call from app or emulator with Callable HTTPS function.
exports.sendTestPush = onCall({region: 'us-central1'}, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'You must be signed in.');
  }

  const uid = request.auth.uid;
  const userSnap = await db.collection('users').doc(uid).get();
  const token = userSnap.data()?.fcmToken;

  if (!token) {
    throw new HttpsError('failed-precondition', 'No fcmToken on current user.');
  }

  const title = trimText(request.data?.title || 'Тестове повідомлення', 60);
  const body = trimText(request.data?.body || 'Push notifications are working.', 160);

  const response = await messaging.send({
    token,
    notification: {title, body},
    data: {type: 'chat_message', senderId: uid, receiverId: uid},
    android: {
      priority: 'high',
      notification: {channelId: 'chat_messages', sound: 'default'}
    },
    apns: {
      headers: {'apns-priority': '10'},
      payload: {aps: {sound: 'default'}}
    }
  });

  return {ok: true, response};
});

// Auto-complete active trips when planned arrival time has passed.
exports.completeFinishedTrips = onSchedule(
  {
    schedule: 'every 5 minutes',
    timeZone: 'Europe/Kyiv',
    region: 'us-central1'
  },
  async () => {
    const now = new Date();
    const tripsSnap = await db.collection('trips').where('status', '==', 'active').get();

    if (tripsSnap.empty) {
      logger.info('No active trips to process.');
      return;
    }

    let updated = 0;
    let backfilled = 0;
    let skipped = 0;
    let batch = db.batch();
    let pendingBatchUpdates = 0;

    async function flushBatchIfNeeded(force = false) {
      if (pendingBatchUpdates === 0) return;
      if (!force && pendingBatchUpdates < 450) return;
      await batch.commit();
      batch = db.batch();
      pendingBatchUpdates = 0;
    }

    for (const doc of tripsSnap.docs) {
      const data = doc.data() || {};
      const departureTime = parseDate(data.departureTime);
      if (!departureTime) {
        skipped += 1;
        continue;
      }

      const {minutes, backfilled: shouldBackfill} = resolveEstimatedMinutes(data);
      if (minutes <= 0) {
        skipped += 1;
        continue;
      }
      const plannedArrival = new Date(departureTime.getTime() + minutes * 60 * 1000);
      const payload = {};

      if (shouldBackfill) {
        payload.estimatedDurationMinutes = minutes;
      }

      if (plannedArrival <= now) {
        payload.status = 'completed';
        payload.completedAt = admin.firestore.FieldValue.serverTimestamp();
      }

      const hasPayload = Object.keys(payload).length > 0;
      if (hasPayload) {
        batch.update(doc.ref, payload);
        pendingBatchUpdates += 1;
        await flushBatchIfNeeded();

        if (payload.status === 'completed') {
          updated += 1;
        }
        if (Object.prototype.hasOwnProperty.call(payload, 'estimatedDurationMinutes')) {
          backfilled += 1;
        }
      } else {
        skipped += 1;
      }
    }

    await flushBatchIfNeeded(true);

    logger.info('Trip completion cron finished.', {
      processed: tripsSnap.size,
      updated,
      backfilled,
      skipped
    });
  }
);

