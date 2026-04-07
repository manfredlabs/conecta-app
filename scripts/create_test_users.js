// Cria usuários de teste para cada role
// Rode com: node create_test_users.js

const { initializeApp } = require('firebase/app');
const { getAuth, createUserWithEmailAndPassword } = require('firebase/auth');
const { getFirestore, doc, setDoc, getDocs, collection, query, where, limit } = require('firebase/firestore');
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
  const auth = getAuth(app);
  const db = getFirestore(app);

  // Buscar IDs reais do Firestore
  console.log('\n=== Buscando dados existentes ===\n');

  const congSnap = await getDocs(query(collection(db, 'congregations'), limit(1)));
  const congId = congSnap.docs[0].id;
  const congName = congSnap.docs[0].data().name;
  console.log(`Congregação: ${congName} (${congId})`);

  const supSnap = await getDocs(query(collection(db, 'supervisions'), where('congregationId', '==', congId), limit(1)));
  const supId = supSnap.docs[0].id;
  const supName = supSnap.docs[0].data().name;
  console.log(`Supervisão: ${supName} (${supId})`);

  const cellSnap = await getDocs(query(collection(db, 'cells'), where('supervisionId', '==', supId), limit(1)));
  const cellId = cellSnap.docs[0].id;
  const cellName = cellSnap.docs[0].data().name;
  console.log(`Célula: ${cellName} (${cellId})`);

  // Definir usuários de teste
  const users = [
    {
      email: 'lider@teste.com',
      name: 'Maria Líder',
      role: 'leader',
      congregationId: congId,
      supervisionId: supId,
      cellId: cellId,
    },
    {
      email: 'supervisor@teste.com',
      name: 'João Supervisor',
      role: 'supervisor',
      congregationId: congId,
      supervisionId: supId,
      cellId: null,
    },
    {
      email: 'pastor@teste.com',
      name: 'Pr. Paulo Pastor',
      role: 'pastor',
      congregationId: congId,
      supervisionId: null,
      cellId: null,
    },
    {
      email: 'presidente@teste.com',
      name: 'Pr. Roberto Presidente',
      role: 'admin',
      congregationId: null,
      supervisionId: null,
      cellId: null,
    },
  ];

  console.log('\n=== Criando usuários de teste ===\n');

  for (const u of users) {
    try {
      const cred = await createUserWithEmailAndPassword(auth, u.email, '123456');
      const uid = cred.user.uid;

      await setDoc(doc(db, 'users', uid), {
        name: u.name,
        email: u.email,
        role: u.role,
        congregationId: u.congregationId,
        supervisionId: u.supervisionId,
        cellId: u.cellId,
      });

      console.log(`✅ ${u.role.padEnd(10)} | ${u.email.padEnd(25)} | ${u.name}`);
    } catch (e) {
      if (e.code === 'auth/email-already-in-use') {
        console.log(`⚠️  ${u.role.padEnd(10)} | ${u.email.padEnd(25)} | Já existe`);
      } else {
        console.log(`❌ ${u.role.padEnd(10)} | ${u.email.padEnd(25)} | Erro: ${e.message}`);
      }
    }
  }

  // Atualizar célula com leaderId
  const leaderSnap = await getDocs(query(collection(db, 'users'), where('email', '==', 'lider@teste.com'), limit(1)));
  if (!leaderSnap.empty) {
    const leaderId = leaderSnap.docs[0].id;
    const { updateDoc } = require('firebase/firestore');
    await updateDoc(doc(db, 'cells', cellId), {
      leaderId: leaderId,
      leaderName: 'Maria Líder',
    });
    console.log(`\n🔗 Célula "${cellName}" vinculada à líder Maria`);
  }

  console.log('\n=== Logins de teste ===\n');
  console.log('  Líder:        lider@teste.com       / 123456');
  console.log('  Supervisor:   supervisor@teste.com   / 123456');
  console.log('  Pastor:       pastor@teste.com       / 123456');
  console.log('  Presidente:   presidente@teste.com   / 123456');
  console.log('  Admin:        caio@manfredlabs.com   / 123456');
  console.log('');

  process.exit(0);
}

main().catch(console.error);
