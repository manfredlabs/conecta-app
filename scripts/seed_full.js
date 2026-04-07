// seed_full.js — Limpa e recria TODOS os dados do Firestore + Auth
// Rode com: node seed_full.js
//
// Hierarquia:
//   1 Congregação → 5 Supervisões → 50 Células
//   ~550 Membros (batizados) + ~175 Visitantes (alguns batizados)
//   6 Usuários de login (admin, pastor, 2 supervisores, 2 líderes)

const { initializeApp } = require('firebase/app');
const { getAuth, createUserWithEmailAndPassword, signInWithEmailAndPassword } = require('firebase/auth');
const {
  getFirestore, collection, addDoc, getDocs, deleteDoc,
  doc, setDoc, writeBatch, Timestamp,
} = require('firebase/firestore');
const fs = require('fs');
const path = require('path');

// ═══════════════════════════════════════════
//  DADOS PARA GERAÇÃO
// ═══════════════════════════════════════════

const primeirosNomes = [
  'Ana', 'Bruno', 'Carla', 'Daniel', 'Eliane', 'Felipe', 'Gabriela', 'Hugo',
  'Isabela', 'João', 'Karen', 'Lucas', 'Mariana', 'Nicolas', 'Olivia', 'Paulo',
  'Rafaela', 'Samuel', 'Tatiane', 'Ulisses', 'Vanessa', 'Wagner', 'Yasmin',
  'Amanda', 'Breno', 'Camila', 'Diego', 'Eduarda', 'Fábio', 'Giovana', 'Henrique',
  'Ivana', 'Julio', 'Kátia', 'Leonardo', 'Michele', 'Natan', 'Patrícia', 'Roberto',
  'Sara', 'Thiago', 'Valéria', 'Wesley', 'Renata', 'Pedro', 'Lúcia',
  'Marcos', 'Priscila', 'André', 'Beatriz', 'Cláudio', 'Débora', 'Estêvão', 'Fernanda',
  'Gustavo', 'Helena', 'Igor', 'Juliana', 'Kleber', 'Lorena', 'Mateus', 'Natália',
  'Otávio', 'Paloma', 'Raul', 'Simone', 'Tânia', 'Vinícius', 'Wanda', 'Yuri',
  'Alice', 'Bernardo', 'Cecília', 'Davi', 'Emília', 'Francisco', 'Gisele', 'Heitor',
  'Lívia', 'Miguel', 'Nicole', 'Rafael', 'Sophia', 'Arthur', 'Clara', 'Emanuel',
];

const sobrenomes = [
  'Silva', 'Santos', 'Oliveira', 'Souza', 'Costa', 'Pereira', 'Ferreira', 'Lima',
  'Almeida', 'Ribeiro', 'Rodrigues', 'Gomes', 'Martins', 'Araújo', 'Barbosa',
  'Carvalho', 'Nascimento', 'Mendes', 'Dias', 'Moura', 'Freitas', 'Cardoso',
  'Vieira', 'Rocha', 'Correia', 'Nunes', 'Monteiro', 'Teixeira', 'Pinto', 'Moreira',
  'Campos', 'Batista', 'Reis', 'Miranda', 'Lopes', 'Melo', 'Borges', 'Pires',
  'Machado', 'Castro', 'Duarte', 'Ramos', 'Cunha', 'Azevedo', 'Fonseca', 'Brito',
];

const nomesCelulas = [
  'Vida Nova', 'Resgate', 'Boa Semente', 'Manancial', 'Rocha Firme',
  'Fortaleza', 'Bênção', 'Aliança', 'Graça', 'Esperança',
  'Renovo', 'Shekinah', 'Moriá', 'Eben-Ézer', 'Emanuel',
  'Nissi', 'Shalom', 'Refúgio', 'Adonai', 'El Shaday',
  'Rapha', 'Tsidkenu', 'Jireh', 'Sabaoth', 'Filadélfia',
  'Esmirna', 'Pérgamo', 'Tiatira', 'Sardes', 'Laodiceia',
  'Beréia', 'Antioquia', 'Éfeso', 'Corinto', 'Filipos',
  'Tessalônica', 'Colossos', 'Damasco', 'Betânia', 'Nazaré',
  'Jerusalém', 'Samaria', 'Galiléia', 'Hebrom', 'Belém',
  'Canaã', 'Sinai', 'Jordão', 'Getsêmani', 'Tabor',
];

const nomesSupervisoes = ['Alpha', 'Beta', 'Gama', 'Delta', 'Epsilon'];

const diasSemana = ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado'];

const ruas = [
  'Rua das Flores', 'Av. Brasil', 'Rua São Paulo', 'Rua Esperança',
  'Av. Liberdade', 'Rua da Paz', 'Rua dos Apóstolos', 'Av. Principal',
  'Rua Bela Vista', 'Rua Nova', 'Rua Dois de Fevereiro', 'Av. Santos Dumont',
  'Rua Barão de Mesquita', 'Rua Conde de Bonfim', 'Av. Maracanã',
];

// ═══════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════

function rand(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function shuffle(arr) {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

const usedNames = new Set();
function gerarNomeUnico() {
  let name, attempts = 0;
  do {
    const first = pick(primeirosNomes);
    const last = pick(sobrenomes);
    name = attempts > 300
      ? `${first} ${String.fromCharCode(65 + rand(0, 25))}. ${last}`
      : `${first} ${last}`;
    attempts++;
  } while (usedNames.has(name));
  usedNames.add(name);
  return name;
}

function gerarTelefone() {
  const ddd = pick(['11', '21', '31', '41', '51', '61', '71', '81', '85', '27']);
  return `(${ddd}) 9${rand(1000, 9999)}-${rand(1000, 9999)}`;
}

function gerarEndereco() {
  return `${pick(ruas)}, ${rand(10, 999)}`;
}

function gerarDataNascimento() {
  return new Date(rand(1960, 2005), rand(0, 11), rand(1, 28));
}

// ═══════════════════════════════════════════
//  LIMPAR COLEÇÕES
// ═══════════════════════════════════════════

async function limparColecao(db, nome) {
  const snap = await getDocs(collection(db, nome));
  if (snap.size === 0) return;

  // Delete in batches of 400
  let batch = writeBatch(db);
  let count = 0;
  for (const d of snap.docs) {
    batch.delete(doc(db, nome, d.id));
    count++;
    if (count % 400 === 0) {
      await batch.commit();
      batch = writeBatch(db);
    }
  }
  if (count % 400 !== 0) await batch.commit();
  console.log(`  ✕ ${count} docs de '${nome}'`);
}

// ═══════════════════════════════════════════
//  MAIN
// ═══════════════════════════════════════════

async function main() {
  // Firebase init
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

  const PASSWORD = '123456';

  // ─── FASE 0: LIMPEZA ───
  console.log('\n══════════════════════════════════════');
  console.log('  FASE 0 — LIMPANDO TUDO');
  console.log('══════════════════════════════════════\n');

  for (const col of ['meetings', 'members', 'cell_members', 'people', 'cells', 'supervisions', 'congregations', 'users']) {
    await limparColecao(db, col);
  }

  // ─── FASE 1: HIERARQUIA ───
  console.log('\n══════════════════════════════════════');
  console.log('  FASE 1 — CONGREGAÇÃO + SUPERVISÕES + CÉLULAS');
  console.log('══════════════════════════════════════\n');

  // 1 Congregação
  const congRef = await addDoc(collection(db, 'congregations'), {
    name: 'Congregação Central',
    pastorId: null,
    pastorName: null,
  });
  const congId = congRef.id;
  console.log(`  📍 Congregação Central (${congId})`);

  // 5 Supervisões
  const supervisions = [];
  for (let s = 0; s < 5; s++) {
    const supRef = await addDoc(collection(db, 'supervisions'), {
      name: `Supervisão ${nomesSupervisoes[s]}`,
      congregationId: congId,
      supervisorId: null,
      supervisorName: null,
    });
    supervisions.push({ id: supRef.id, name: nomesSupervisoes[s] });
    console.log(`  🔷 Supervisão ${nomesSupervisoes[s]} (${supRef.id})`);
  }

  // 50 Células (10 por supervisão)
  const shuffledCellNames = shuffle(nomesCelulas);
  const cells = [];
  let cellIdx = 0;

  for (const sup of supervisions) {
    for (let c = 0; c < 10; c++) {
      const cellName = `Célula ${shuffledCellNames[cellIdx]}`;
      const cellRef = await addDoc(collection(db, 'cells'), {
        name: cellName,
        supervisionId: sup.id,
        congregationId: congId,
        leaderId: null,
        leaderName: null,
        meetingDay: pick(diasSemana),
        meetingTime: `${rand(18, 20)}:${pick(['00', '30'])}`,
        address: gerarEndereco(),
      });
      cells.push({
        id: cellRef.id,
        name: cellName,
        supervisionId: sup.id,
        leaderMemberId: null,
        leaderName: null,
      });
      cellIdx++;
    }
    console.log(`    ✓ 10 células criadas na Supervisão ${sup.name}`);
  }

  // ─── FASE 2: MEMBROS ───
  console.log('\n══════════════════════════════════════');
  console.log('  FASE 2 — MEMBROS (todos batizados)');
  console.log('══════════════════════════════════════\n');

  // Nomes pré-definidos para líderes que terão login
  // cell[0]  → pastor (também líder)
  // cell[10] → supervisor1 (também líder)
  // cell[20] → lider1
  // cell[30] → lider2
  const preAssignedNames = {
    0: 'Roberto Vieira',     // pastor
    10: 'Marcos Teixeira',   // supervisor1 + líder
    20: 'Ana Paula Silva',   // lider1
    30: 'Lucas Ferreira',    // lider2
  };

  let totalMembers = 0;
  let batchCount = 0;
  let batch = writeBatch(db);

  // Track people refs to avoid duplicates (name → personDocId)
  const personMap = new Map();

  for (let ci = 0; ci < cells.length; ci++) {
    const cell = cells[ci];
    const numMembers = rand(8, 15);

    for (let m = 0; m < numMembers; m++) {
      const isLeader = (m === 0);
      let name;

      if (isLeader && preAssignedNames[ci]) {
        name = preAssignedNames[ci];
        usedNames.add(name);
      } else {
        name = gerarNomeUnico();
      }

      const gender = pick(['M', 'F']);
      const birthDate = gerarDataNascimento();
      const phone = Math.random() > 0.15 ? gerarTelefone() : null;

      // Old members collection (legacy)
      const memberRef = doc(collection(db, 'members'));
      batch.set(memberRef, {
        name,
        phone,
        cellId: cell.id,
        supervisionId: cell.supervisionId,
        congregationId: congId,
        isVisitor: false,
        isLeader,
        isActive: true,
        gender,
        baptized: true,
        birthDate: Timestamp.fromDate(birthDate),
        email: null,
      });

      // New people collection (one per person)
      let personId;
      if (personMap.has(name)) {
        personId = personMap.get(name);
      } else {
        const personRef = doc(collection(db, 'people'));
        personId = personRef.id;
        batch.set(personRef, {
          name,
          phone,
          gender,
          baptized: true,
          birthDate: Timestamp.fromDate(birthDate),
          email: null,
          congregationId: congId,
          userId: null,
        });
        personMap.set(name, personId);
      }

      // New cell_members collection
      const cmRef = doc(collection(db, 'cell_members'));
      batch.set(cmRef, {
        personId,
        personName: name,
        cellId: cell.id,
        supervisionId: cell.supervisionId,
        congregationId: congId,
        isLeader,
        isHelper: false,
        isVisitor: false,
        isActive: true,
      });

      if (isLeader) {
        cell.leaderMemberId = memberRef.id;
        cell.leaderName = name;
      }

      batchCount += 3; // 3 docs per member (members + people + cell_members), minus person if deduped
      totalMembers++;

      if (batchCount >= 380) {
        await batch.commit();
        batch = writeBatch(db);
        batchCount = 0;
        process.stdout.write('.');
      }
    }
  }

  // Commit remaining
  if (batchCount > 0) {
    await batch.commit();
    batch = writeBatch(db);
    batchCount = 0;
  }

  console.log(`\n  ✓ ${totalMembers} membros criados (todos batizados)`);

  // ─── FASE 3: ATUALIZAR LÍDERES NAS CÉLULAS ───
  console.log('\n══════════════════════════════════════');
  console.log('  FASE 3 — VINCULANDO LÍDERES ÀS CÉLULAS');
  console.log('══════════════════════════════════════\n');

  for (const cell of cells) {
    batch.update(doc(db, 'cells', cell.id), {
      leaderName: cell.leaderName,
    });
    batchCount++;
    if (batchCount >= 400) {
      await batch.commit();
      batch = writeBatch(db);
      batchCount = 0;
    }
  }
  if (batchCount > 0) {
    await batch.commit();
    batch = writeBatch(db);
    batchCount = 0;
  }
  console.log(`  ✓ 50 líderes vinculados`);

  // ─── FASE 4: VISITANTES ───
  console.log('\n══════════════════════════════════════');
  console.log('  FASE 4 — VISITANTES');
  console.log('══════════════════════════════════════\n');

  let totalVisitors = 0;
  let baptizedVisitors = 0;

  for (const cell of cells) {
    const numVisitors = rand(2, 5);

    for (let v = 0; v < numVisitors; v++) {
      const name = gerarNomeUnico();
      const gender = pick(['M', 'F']);
      const isBaptized = Math.random() < 0.4; // 40% batizados
      const birthDate = gerarDataNascimento();
      const phone = Math.random() > 0.4 ? gerarTelefone() : null;

      // Old members collection (legacy)
      const ref = doc(collection(db, 'members'));
      batch.set(ref, {
        name,
        phone,
        cellId: cell.id,
        supervisionId: cell.supervisionId,
        congregationId: congId,
        isVisitor: true,
        isLeader: false,
        isActive: true,
        gender,
        baptized: isBaptized,
        birthDate: Timestamp.fromDate(birthDate),
        email: null,
      });

      // New people collection
      let personId;
      if (personMap.has(name)) {
        personId = personMap.get(name);
      } else {
        const personRef = doc(collection(db, 'people'));
        personId = personRef.id;
        batch.set(personRef, {
          name,
          phone,
          gender,
          baptized: isBaptized,
          birthDate: Timestamp.fromDate(birthDate),
          email: null,
          congregationId: congId,
          userId: null,
        });
        personMap.set(name, personId);
      }

      // New cell_members collection
      const cmRef = doc(collection(db, 'cell_members'));
      batch.set(cmRef, {
        personId,
        personName: name,
        cellId: cell.id,
        supervisionId: cell.supervisionId,
        congregationId: congId,
        isLeader: false,
        isHelper: false,
        isVisitor: true,
        isActive: true,
      });

      totalVisitors++;
      if (isBaptized) baptizedVisitors++;
      batchCount += 3;

      if (batchCount >= 380) {
        await batch.commit();
        batch = writeBatch(db);
        batchCount = 0;
        process.stdout.write('.');
      }
    }
  }

  if (batchCount > 0) {
    await batch.commit();
    batch = writeBatch(db);
    batchCount = 0;
  }

  console.log(`\n  ✓ ${totalVisitors} visitantes criados (${baptizedVisitors} batizados, ${totalVisitors - baptizedVisitors} não batizados)`);

  // ─── FASE 5: USUÁRIOS DE LOGIN ───
  console.log('\n══════════════════════════════════════');
  console.log('  FASE 5 — CRIANDO LOGINS (Firebase Auth)');
  console.log('══════════════════════════════════════\n');

  const authUsers = [
    {
      email: 'admin@conecta.com',
      name: 'Caio Admin',
      role: 'admin',
      congregationId: congId,
      supervisionId: null,
      cellId: null,
      desc: 'Admin geral',
    },
    {
      email: 'pastor@conecta.com',
      name: 'Pr. Roberto Vieira',
      role: 'pastor',
      congregationId: congId,
      supervisionId: supervisions[0].id,  // supervisiona Alpha
      cellId: cells[0].id,                // lidera célula 0
      desc: 'Pastor + Supervisor Alpha + Líder célula',
    },
    {
      email: 'supervisor1@conecta.com',
      name: 'Marcos Teixeira',
      role: 'supervisor',
      congregationId: congId,
      supervisionId: supervisions[1].id,  // supervisiona Beta
      cellId: cells[10].id,               // lidera célula 10
      desc: 'Supervisor Beta + Líder célula',
    },
    {
      email: 'supervisor2@conecta.com',
      name: 'Ricardo Almeida',
      role: 'supervisor',
      congregationId: congId,
      supervisionId: supervisions[2].id,  // supervisiona Gama
      cellId: null,                       // NÃO lidera célula
      desc: 'Supervisor Gama (sem célula)',
    },
    {
      email: 'lider1@conecta.com',
      name: 'Ana Paula Silva',
      role: 'leader',
      congregationId: congId,
      supervisionId: cells[20].supervisionId,
      cellId: cells[20].id,
      desc: `Líder da ${cells[20].name}`,
    },
    {
      email: 'lider2@conecta.com',
      name: 'Lucas Ferreira',
      role: 'leader',
      congregationId: congId,
      supervisionId: cells[30].supervisionId,
      cellId: cells[30].id,
      desc: `Líder da ${cells[30].name}`,
    },
  ];

  const createdUsers = [];

  for (const u of authUsers) {
    let uid = null;

    try {
      const cred = await createUserWithEmailAndPassword(auth, u.email, PASSWORD);
      uid = cred.user.uid;
    } catch (err) {
      if (err.code === 'auth/email-already-in-use') {
        try {
          const cred = await signInWithEmailAndPassword(auth, u.email, PASSWORD);
          uid = cred.user.uid;
        } catch (signInErr) {
          console.log(`  ✗ ${u.email} — Erro: ${signInErr.message}`);
          continue;
        }
      } else {
        console.log(`  ✗ ${u.email} — Erro: ${err.message}`);
        continue;
      }
    }

    // Create users doc
    await setDoc(doc(db, 'users', uid), {
      name: u.name,
      email: u.email,
      role: u.role,
      congregationId: u.congregationId,
      supervisionId: u.supervisionId,
      cellId: u.cellId,
    });

    // Link userId to person doc (find by name)
    const personName = u.name.replace('Pr. ', ''); // strip title
    if (personMap.has(personName)) {
      const personId = personMap.get(personName);
      await setDoc(doc(db, 'people', personId), { userId: uid }, { merge: true });
    }

    // Link pastor to congregation
    if (u.role === 'pastor') {
      await setDoc(doc(db, 'congregations', congId), {
        pastorId: uid,
        pastorName: u.name,
      }, { merge: true });
    }

    // Link supervisor/pastor to supervision
    if (u.supervisionId && (u.role === 'supervisor' || u.role === 'pastor')) {
      await setDoc(doc(db, 'supervisions', u.supervisionId), {
        supervisorId: uid,
        supervisorName: u.name,
      }, { merge: true });
    }

    // Link to cell as leader
    if (u.cellId) {
      await setDoc(doc(db, 'cells', u.cellId), {
        leaderId: uid,
        leaderName: u.name,
      }, { merge: true });
    }

    createdUsers.push(u);
    console.log(`  ✓ ${u.role.padEnd(10)} | ${u.email.padEnd(25)} | ${u.desc}`);
  }

  // ─── RESUMO FINAL ───
  console.log('\n══════════════════════════════════════');
  console.log('  RESUMO FINAL');
  console.log('══════════════════════════════════════\n');
  console.log(`  📍  1 Congregação`);
  console.log(`  🔷  ${supervisions.length} Supervisões (10 células cada)`);
  console.log(`  🟢  ${cells.length} Células`);
  console.log(`  👤  ${totalMembers} Membros (todos batizados)`);
  console.log(`  👋  ${totalVisitors} Visitantes (${baptizedVisitors} batizados)`);
  console.log(`  🧑  ${personMap.size} People (nova collection)`);
  console.log(`  🔗  ${totalMembers + totalVisitors} Cell Members (nova collection)`);
  console.log(`  🔑  ${createdUsers.length} Logins criados`);

  console.log('\n  ── LOGINS (senha: 123456) ──\n');
  for (const u of createdUsers) {
    console.log(`    ${u.role.padEnd(10)}  ${u.email.padEnd(25)}  ${u.desc}`);
  }

  console.log('\n  ── HIERARQUIA ──\n');
  console.log('  Congregação Central');
  for (let si = 0; si < supervisions.length; si++) {
    const sup = supervisions[si];
    console.log(`    └─ Supervisão ${sup.name}`);
    for (let ci = si * 10; ci < (si + 1) * 10; ci++) {
      const cell = cells[ci];
      const marker = ci === (si + 1) * 10 - 1 ? '└─' : '├─';
      console.log(`       ${marker} ${cell.name} (${cell.leaderName})`);
    }
  }

  console.log('\n══════════════════════════════════════');
  console.log('  PRONTO! Hot restart no app pra ver os dados.');
  console.log('══════════════════════════════════════\n');

  process.exit(0);
}

main().catch(err => {
  console.error('\n❌ ERRO:', err);
  process.exit(1);
});
