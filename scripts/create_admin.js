// Script para criar o primeiro usuário admin no Firebase
// Rode com: node create_admin.js

const { initializeApp } = require('firebase/app');
const { getAuth, createUserWithEmailAndPassword } = require('firebase/auth');
const { getFirestore, doc, setDoc } = require('firebase/firestore');
const readline = require('readline');
const fs = require('fs');
const path = require('path');

async function main() {
  // Ler apiKey do firebase_options.dart
  const optionsPath = path.join(__dirname, '..', 'lib', 'firebase_options.dart');
  const content = fs.readFileSync(optionsPath, 'utf8');
  const apiKeyMatch = content.match(/apiKey:\s*'([^']+)'/);
  const appIdMatch = content.match(/appId:\s*'([^']+)'/);
  const msgSenderMatch = content.match(/messagingSenderId:\s*'([^']+)'/);
  const storageBucketMatch = content.match(/storageBucket:\s*'([^']+)'/);

  if (!apiKeyMatch) {
    console.error('Não consegui encontrar a apiKey no firebase_options.dart');
    process.exit(1);
  }

  const firebaseConfig = {
    apiKey: apiKeyMatch[1],
    projectId: 'conecta-64c31',
    appId: appIdMatch ? appIdMatch[1] : '',
    messagingSenderId: msgSenderMatch ? msgSenderMatch[1] : '',
    storageBucket: storageBucketMatch ? storageBucketMatch[1] : '',
  };

  const app = initializeApp(firebaseConfig);
  const auth = getAuth(app);
  const db = getFirestore(app);

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  const ask = (q) => new Promise((resolve) => rl.question(q, resolve));

  console.log('\n=== Criar Usuario Admin - Conecta ===\n');

  const name = await ask('Nome: ');
  const email = await ask('Email: ');
  const password = await ask('Senha (min 6 caracteres): ');

  try {
    const credential = await createUserWithEmailAndPassword(auth, email, password);
    console.log(`\nUsuario criado no Auth: ${credential.user.uid}`);

    await setDoc(doc(db, 'users', credential.user.uid), {
      name: name,
      email: email,
      role: 'admin',
      congregationId: null,
      supervisionId: null,
      cellId: null,
    });

    console.log('Documento do usuario criado no Firestore com role: admin');
    console.log('\nAgora voce pode logar no app com esse email e senha!');
  } catch (error) {
    console.error('Erro:', error.message);
  }

  rl.close();
  process.exit(0);
}

main();
