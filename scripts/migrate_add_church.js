// migrate_add_church.js — Migração: adiciona churchId em todos os docs existentes
// Rode com: node migrate_add_church.js
//
// O que faz:
//   1. Cria um doc em 'churches' (se não existir) para a igreja atual
//   2. Percorre TODAS as collections e adiciona churchId em todos os docs
//
// Collections afetadas:
//   users, people, congregations, supervisions, cells,
//   members, cell_members, meetings, approval_requests

const { initializeApp } = require('firebase/app');
const {
  getFirestore, collection, getDocs, doc, updateDoc,
  addDoc, query, where, Timestamp,
} = require('firebase/firestore');
const fs = require('fs');
const path = require('path');

// ══════════════════════════════════════
//  CONFIGURAÇÃO DA IGREJA
// ══════════════════════════════════════

const CHURCH_NAME = 'Igreja Maranata';
const CHURCH_CODE = 'maranata';

// ══════════════════════════════════════

async function main() {
  // Firebase init (reads config from firebase_options.dart)
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

  console.log('\n══════════════════════════════════════');
  console.log('  MIGRAÇÃO: Adicionar churchId');
  console.log('══════════════════════════════════════\n');

  // ── FASE 1: Criar/encontrar church doc ──
  console.log('1. Buscando/criando igreja...');

  let churchId;
  const churchesSnap = await getDocs(
    query(collection(db, 'churches'), where('code', '==', CHURCH_CODE))
  );

  if (churchesSnap.empty) {
    const churchRef = await addDoc(collection(db, 'churches'), {
      name: CHURCH_NAME,
      code: CHURCH_CODE,
      createdAt: Timestamp.now(),
    });
    churchId = churchRef.id;
    console.log(`   ✅ Igreja criada: ${CHURCH_NAME} (${churchId})`);
  } else {
    churchId = churchesSnap.docs[0].id;
    console.log(`   ✅ Igreja encontrada: ${CHURCH_NAME} (${churchId})`);
  }

  // ── FASE 2: Backfill churchId em todas as collections ──
  const collections = [
    'users',
    'people',
    'congregations',
    'supervisions',
    'cells',
    'members',
    'cell_members',
    'meetings',
    'approval_requests',
  ];

  let totalUpdated = 0;

  for (const col of collections) {
    console.log(`\n2. Atualizando ${col}...`);
    const snap = await getDocs(collection(db, col));
    let count = 0;

    for (const docSnap of snap.docs) {
      const data = docSnap.data();
      if (data.churchId === churchId) {
        continue; // já tem churchId correto
      }
      await updateDoc(doc(db, col, docSnap.id), { churchId });
      count++;
    }

    console.log(`   ✅ ${count}/${snap.size} docs atualizados em ${col}`);
    totalUpdated += count;
  }

  console.log('\n══════════════════════════════════════');
  console.log(`  MIGRAÇÃO CONCLUÍDA!`);
  console.log(`  Igreja: ${CHURCH_NAME} (${churchId})`);
  console.log(`  Total de docs atualizados: ${totalUpdated}`);
  console.log('══════════════════════════════════════\n');

  process.exit(0);
}

main().catch((err) => {
  console.error('Erro na migração:', err);
  process.exit(1);
});
