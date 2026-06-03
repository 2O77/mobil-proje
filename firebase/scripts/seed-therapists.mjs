import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import admin from 'firebase-admin';

const CONFIG = {
  serviceAccountPath: './service_account_key.json',
  therapistPassword: 'GucluSifre123',
  therapistEmailDomain: 'auticare.app',
};

if (!CONFIG.therapistPassword || CONFIG.therapistPassword.length < 6) {
  console.error('CONFIG.therapistPassword en az 6 karakter olmalı.');
  process.exit(1);
}

const serviceAccountFile = resolve(process.cwd(), CONFIG.serviceAccountPath);
const serviceAccount = JSON.parse(readFileSync(serviceAccountFile, 'utf8'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const auth = admin.auth();
const db = admin.firestore();

const names = [
  'Dr. Ayşe Yılmaz',
  'Dr. Mehmet Kaya',
  'Dr. Zeynep Demir',
  'Dr. Can Öztürk',
  'Dr. Elif Şahin',
  'Dr. Burak Aydın',
  'Dr. Selin Arslan',
  'Dr. Emre Çelik',
  'Dr. Deniz Koç',
  'Dr. Mert Yıldız',
];

for (let i = 0; i < 10; i++) {
  const n = i + 1;
  const email = `terapist${n}@${CONFIG.therapistEmailDomain}`;
  const displayName = names[i];
  let uid;
  try {
    const u = await auth.createUser({ email, password: CONFIG.therapistPassword, displayName });
    uid = u.uid;
    console.log(`Oluşturuldu: ${email} -> ${uid}`);
  } catch (e) {
    if (e.code === 'auth/email-already-exists') {
      const existing = await auth.getUserByEmail(email);
      uid = existing.uid;
      await auth.updateUser(uid, { password: CONFIG.therapistPassword, displayName });
      console.log(`Güncellendi (mevcut): ${email} -> ${uid}`);
    } else {
      throw e;
    }
  }
  const userRef = db.collection('users').doc(uid);
  await userRef.set(
    {
      role: 'therapist',
      displayName,
      caregiverIds: [],
      medications: [],
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await db
    .collection('therapists')
    .doc(uid)
    .set({
      displayName,
      sortOrder: n,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

console.log('Tamam: 10 terapist (Auth + users + therapists).');
