const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();
const SYSTEM_CHAT_USER_ID = 'poikhali_system';
const SYSTEM_CHAT_NAME = 'Поїхали Разом';

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

async function sendSystemTripMessage({tripId, receiverId, text, type}) {
  if (!receiverId) return;
  await db.collection('messages').add({
    tripId,
    senderId: SYSTEM_CHAT_USER_ID,
    receiverId,
    text,
    type,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
    isRead: false,
    isSystem: true
  });
}

async function notifyTripCompletion(tripId, tripData) {
  const passengerIds = Array.isArray(tripData.passengers)
    ? tripData.passengers.map((id) => String(id)).filter(Boolean)
    : [];
  const recipients = [String(tripData.driverId || ''), ...passengerIds]
    .map((id) => id.trim())
    .filter(Boolean);
  const uniqueRecipients = [...new Set(recipients)];

  for (const receiverId of uniqueRecipients) {
    const isDriver = receiverId === String(tripData.driverId || '');
    await sendSystemTripMessage({
      tripId,
      receiverId,
      type: 'trip_completed',
      text: isDriver
        ? 'Поїздка завершена. Ви можете переглянути відгуки від пасажирів.'
        : 'Поїздка завершена. Ви можете залишити відгук про водія.'
    });
  }
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
      senderId === SYSTEM_CHAT_USER_ID
        ? Promise.resolve(null)
        : db.collection('users').doc(senderId).get(),
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

    const senderName = senderId === SYSTEM_CHAT_USER_ID
      ? SYSTEM_CHAT_NAME
      : (senderSnap?.exists ? (senderSnap.data()?.name || 'Нове повідомлення') : 'Нове повідомлення');

    const metadata = message.metadata && typeof message.metadata === 'object'
      ? message.metadata
      : {};
    const messageType = String(message.type || '');
    const tripId = String(message.tripId || '');
    const bookingRequestId = String(metadata.bookingRequestId || '');
    const passengerId = String(metadata.passengerId || '');
    const passengerName = String(metadata.passengerName || '');

    const payload = {
      token,
      notification: {
        title: senderName,
        body: messageText || 'Нове повідомлення'
      },
      data: {
        type: 'chat_message',
        messageType,
        senderId: String(senderId),
        receiverId: String(receiverId),
        messageId: String(event.params.messageId || ''),
        tripId,
        bookingRequestId,
        passengerId,
        passengerName,
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
    const tripsSnap = await db.collection('trips').where('status', 'in', ['active', 'in_progress']).get();

    if (tripsSnap.empty) {
      logger.info('No active trips to process.');
      return;
    }

    let updated = 0;
    let backfilled = 0;
    let skipped = 0;

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
      const currentStatus = data.status || 'active';

      if (shouldBackfill) {
        payload.estimatedDurationMinutes = minutes;
      }

      if (plannedArrival > now && (currentStatus === 'active' || currentStatus === 'in_progress')) {
        if (now >= departureTime && currentStatus !== 'in_progress') {
          payload.status = 'in_progress';
          payload.startedAt = admin.firestore.FieldValue.serverTimestamp();
        }
      }

      if (plannedArrival <= now) {
        if (!data.startedAt) {
          payload.startedAt = admin.firestore.FieldValue.serverTimestamp();
        }
        payload.status = 'completed';
        payload.completedAt = admin.firestore.FieldValue.serverTimestamp();
      }

      const hasPayload = Object.keys(payload).length > 0;
      if (hasPayload) {
        await doc.ref.update(payload);
        if (payload.status === 'completed') {
          updated += 1;
          const driverId = String(data.driverId || '').trim();
          if (driverId) {
            await db.collection('users').doc(driverId).set(
              {
                tripsCompleted: admin.firestore.FieldValue.increment(1)
              },
              {merge: true}
            );
          }
          await notifyTripCompletion(doc.id, data);
        }
        if (Object.prototype.hasOwnProperty.call(payload, 'estimatedDurationMinutes')) {
          backfilled += 1;
        }
      } else {
        skipped += 1;
      }
    }


    logger.info('Trip completion cron finished.', {
      processed: tripsSnap.size,
      updated,
      backfilled,
      skipped
    });
  }
);

