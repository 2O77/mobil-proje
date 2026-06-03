const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');

initializeApp();

exports.onSosEventCreated = onDocumentCreated('sos_events/{eventId}', async (event) => {
  const snap = event.data;
  if (!snap) return;

  const data = snap.data();
  const therapistId = data.therapistId;
  if (!therapistId) return;

  const db = getFirestore();
  const [therapistSnap, patientSnap] = await Promise.all([
    db.collection('users').doc(therapistId).get(),
    db.collection('users').doc(data.userId).get(),
  ]);

  const fcmToken = therapistSnap.data()?.fcmToken;
  if (!fcmToken) return;

  const patientName = patientSnap.data()?.displayName || 'Danışan';

  await getMessaging().send({
    token: fcmToken,
    notification: {
      title: 'SOS Alarmı',
      body: `${patientName} SOS gönderdi`,
    },
    data: {
      type: 'sos',
      eventId: event.params.eventId,
      patientId: data.userId,
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'sos',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
        },
      },
    },
  });
});
