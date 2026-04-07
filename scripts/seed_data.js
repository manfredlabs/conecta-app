// Script para popular dados de teste no Firestore
// Rode com: node seed_data.js

const { initializeApp } = require('firebase/app');
const { getFirestore, doc, setDoc, collection, addDoc } = require('firebase/firestore');
const fs = require('fs');
const path = require('path');

async function main() {
  const optionsPath = path.join(__dirname, '..', 'lib', 'firebase_options.dart');
  const content = fs.readFileSync(optionsPath, 'utf8');
  const apiKeyMatch = content.match(/apiKey:\s*'([^']+)'/);
  const appIdMatch = content.match(/appId:\s*'([^']+)'/);

  const firebaseConfig = {
    apiKey: apiKeyMatch[1],
    projectId: 'conecta-64c31',
    appId: appIdMatch ? appIdMatch[1] : '',
  };

  const app = initializeApp(firebaseConfig);
  const db = getFirestore(app);

  const adminUid = 'w8wtIhGGUjcUXdRtepT9V6tSxrw1';

  console.log('\n=== Populando dados de teste ===\n');

  // 1. Criar Congregação
  const congRef = await addDoc(collection(db, 'congregations'), {
    name: 'Congregação Central',
    pastorId: adminUid,
    pastorName: 'Caio',
  });
  console.log('Congregação criada:', congRef.id);

  // 2. Criar Supervisão
  const supRef = await addDoc(collection(db, 'supervisions'), {
    name: 'Supervisão Alpha',
    congregationId: congRef.id,
    supervisorId: adminUid,
    supervisorName: 'Caio',
  });
  console.log('Supervisão criada:', supRef.id);

  // 3. Criar Célula
  const cellRef = await addDoc(collection(db, 'cells'), {
    name: 'Célula Vida Nova',
    supervisionId: supRef.id,
    congregationId: congRef.id,
    leaderId: adminUid,
    leaderName: 'Caio',
    meetingDay: 'Quarta-feira',
    address: 'Rua da Igreja, 123',
  });
  console.log('Célula criada:', cellRef.id);

  // 4. Criar Membros
  const membros = [
    { name: 'Ana Paula', phone: '11999990001' },
    { name: 'Bruno Santos', phone: '11999990002' },
    { name: 'Carla Oliveira', phone: '11999990003' },
    { name: 'Daniel Costa', phone: null },
    { name: 'Eliane Ferreira', phone: '11999990005' },
    { name: 'Felipe Souza', phone: null },
    { name: 'Gabriela Lima', phone: '11999990007' },
    { name: 'Hugo Pereira', phone: '11999990008' },
  ];

  for (const m of membros) {
    await addDoc(collection(db, 'members'), {
      name: m.name,
      phone: m.phone,
      cellId: cellRef.id,
      supervisionId: supRef.id,
      congregationId: congRef.id,
    });
    console.log('  Membro:', m.name);
  }

  console.log('\n=== Dados de teste criados com sucesso! ===');
  console.log('\nAgora atualize o app (hot restart) e voce vera:');
  console.log('- 1 Congregacao (Central)');
  console.log('- 1 Supervisao (Alpha)');
  console.log('- 1 Celula (Vida Nova) com 8 membros');
  console.log('\nTeste registrar uma reuniao marcando presenca!\n');

  process.exit(0);
}

main().catch(console.error);
