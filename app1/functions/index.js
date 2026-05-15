const {onDocumentCreated} = require('firebase-functions/v2/firestore');
const {onCall, HttpsError} = require('firebase-functions/v2/https');
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

