// seed_bulletins.js — Cria boletins mockados de semanas anteriores
// Rode com: node seed_bulletins.js

const { initializeApp } = require('firebase/app');
const {
  getFirestore, collection, addDoc, Timestamp,
} = require('firebase/firestore');
const fs = require('fs');
const path = require('path');

async function main() {
  const optionsPath = path.join(__dirname, '..', 'lib', 'firebase_options.dart');
  const content = fs.readFileSync(optionsPath, 'utf8');
  const apiKeyMatch = content.match(/apiKey:\s*'([^']+)'/);
  const appIdMatch = content.match(/appId:\s*'([^']+)'/);

  const app = initializeApp({
    apiKey: apiKeyMatch[1],
    projectId: 'conecta-64c31',
    appId: appIdMatch ? appIdMatch[1] : '',
  });
  const db = getFirestore(app);

  const churchId = 'gdfJ2ryG71YqUDHybQEj';

  // Segundas-feiras de semanas anteriores
  const bulletins = [
    {
      title: 'Boletim 16/03 - 22/03',
      fileName: 'boletim_16_03.pdf',
      fileUrl: '',
      storagePath: '',
      fileType: 'pdf',
      churchId,
      uploadedBy: 'seed',
      weekStart: Timestamp.fromDate(new Date(2026, 2, 16)), // 16 Mar 2026
      createdAt: Timestamp.fromDate(new Date(2026, 2, 17)),
    },
    {
      title: 'Boletim 23/03 - 29/03',
      fileName: 'boletim_23_03.pdf',
      fileUrl: '',
      storagePath: '',
      fileType: 'pdf',
      churchId,
      uploadedBy: 'seed',
      weekStart: Timestamp.fromDate(new Date(2026, 2, 23)), // 23 Mar 2026
      createdAt: Timestamp.fromDate(new Date(2026, 2, 24)),
    },
    {
      title: 'Boletim 30/03 - 05/04',
      fileName: 'boletim_30_03.docx',
      fileUrl: '',
      storagePath: '',
      fileType: 'docx',
      churchId,
      uploadedBy: 'seed',
      weekStart: Timestamp.fromDate(new Date(2026, 2, 30)), // 30 Mar 2026
      createdAt: Timestamp.fromDate(new Date(2026, 2, 31)),
    },
  ];

  console.log('\nCriando 3 boletins mockados de semanas anteriores...\n');

  for (const b of bulletins) {
    const ref = await addDoc(collection(db, 'bulletins'), b);
    console.log(`  ✅ ${b.title} → ${ref.id}`);
  }

  console.log('\n✅ Pronto! 3 boletins criados.\n');
  process.exit(0);
}

main().catch(console.error);

