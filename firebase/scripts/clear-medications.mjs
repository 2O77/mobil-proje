import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import admin from 'firebase-admin';

const serviceAccountFile = resolve(process.cwd(), './service_account_key.json');
const serviceAccount = JSON.parse(readFileSync(serviceAccountFile, 'utf8'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const db = admin.firestore();

async function clearMedicationsCollection() {
  const snap = await db.collection('medications').get();
  if (snap.empty) {
    console.log('medications koleksiyonu zaten boş.');
    return 0;
  }
  const batch = db.batch();
  for (const doc of snap.docs) {
    batch.delete(doc.ref);
  }
  await batch.commit();
  console.log(`${snap.size} ilaç kaydı silindi.`);
  return snap.size;
}

async function clearUserMedicationFields() {
  const snap = await db.collection('users').get();
  if (snap.empty) {
    console.log('users koleksiyonu boş.');
    return 0;
  }
  let updated = 0;
  for (const doc of snap.docs) {
    const data = doc.data();
    const meds = data.medications;
    if (meds == null || (Array.isArray(meds) && meds.length === 0)) continue;
    await doc.ref.set({ medications: [] }, { merge: true });
    updated += 1;
  }
  console.log(`${updated} kullanıcı profilindeki medications alanı temizlendi.`);
  return updated;
}

const deletedDocs = await clearMedicationsCollection();
const clearedProfiles = await clearUserMedicationFields();
console.log(`Tamamlandı. Silinen kayıt: ${deletedDocs}, temizlenen profil: ${clearedProfiles}`);
process.exit(0);
