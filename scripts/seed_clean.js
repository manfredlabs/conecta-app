// seed_clean.js — Limpa TUDO e recria dados consistentes
// Rode com: node seed_clean.js
//
// Estrutura:
//   3 Congregações → 6 Supervisões → 24 Células
//   ~129 Pessoas (pastores, supervisores, líderes, membros)
//   34 Logins (1 admin + 3 pastores + 6 supervisores + 24 líderes)
//
// Ordem de criação (sem referências circulares):
//   1. Congregações (sem pastor)
//   2. Pessoas (com congregationId)
//   3. Supervisões (sem supervisor)
//   4. Células (sem líder)
//   5. Cell Members (vincula pessoa ↔ célula)
//   6. Auth Users (cria logins)
//   7. Atualiza referências cruzadas

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

const primeirosNomesMasc = [
  'João', 'Lucas', 'Pedro', 'Mateus', 'Gabriel', 'Rafael', 'Bruno', 'Daniel',
  'Felipe', 'Hugo', 'André', 'Carlos', 'Thiago', 'Marcos', 'Ricardo', 'Samuel',
  'Vinícius', 'Diego', 'Gustavo', 'Leonardo', 'Paulo', 'Henrique', 'Fábio',
  'Eduardo', 'Igor', 'Julio', 'Natan', 'Otávio', 'Raul', 'Wesley', 'Kleber',
  'Bernardo', 'Davi', 'Francisco', 'Heitor', 'Miguel', 'Arthur', 'Emanuel',
  'Breno', 'Cláudio', 'Estêvão', 'Yuri', 'Wagner', 'Ulisses', 'Roberto',
];

const primeirosNomesFem = [
  'Ana', 'Maria', 'Carla', 'Gabriela', 'Isabela', 'Karen', 'Mariana', 'Olivia',
  'Rafaela', 'Tatiane', 'Vanessa', 'Yasmin', 'Amanda', 'Camila', 'Eduarda',
  'Giovana', 'Ivana', 'Kátia', 'Michele', 'Patrícia', 'Sara', 'Valéria',
  'Renata', 'Lúcia', 'Priscila', 'Beatriz', 'Débora', 'Fernanda', 'Helena',
  'Juliana', 'Lorena', 'Natália', 'Paloma', 'Simone', 'Tânia', 'Wanda',
  'Alice', 'Cecília', 'Emília', 'Gisele', 'Lívia', 'Nicole', 'Sophia', 'Clara',
  'Eliane',
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
  'Rapha', 'Tsidkenu', 'Jireh', 'Sabaoth',
];

const nomesSupervisoes = ['Alpha', 'Beta', 'Gama', 'Delta', 'Epsilon', 'Zeta'];

const nomesCongregacoes = ['Igreja Central', 'Igreja Norte', 'Igreja Sul'];

const diasSemana = ['Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado'];

const ruas = [
  'Rua das Flores', 'Av. Brasil', 'Rua São Paulo', 'Rua Esperança',
  'Av. Liberdade', 'Rua da Paz', 'Rua dos Apóstolos', 'Av. Principal',
  'Rua Bela Vista', 'Rua Nova', 'Rua Dois de Fevereiro', 'Av. Santos Dumont',
  'Rua Barão de Mesquita', 'Rua Conde de Bonfim', 'Av. Maracanã',
  'Rua Voluntários da Pátria', 'Av. Atlântica', 'Rua do Catete',
  'Rua São Clemente', 'Av. Copacabana', 'Rua Senador Dantas', 'Rua da Glória',
  'Rua Frei Caneca', 'Rua Visconde de Pirajá',
];

// ═══════════════════════════════════════════
//  NOMES PRÉ-DEFINIDOS (pastores, supervisores, líderes)
// ═══════════════════════════════════════════

const pastores = [
  { name: 'Roberto Almeida', gender: 'M', email: 'pastor1@conecta.com', congIdx: 0 },
  { name: 'Marcos Ferreira', gender: 'M', email: 'pastor2@conecta.com', congIdx: 1 },
  { name: 'Daniel Oliveira', gender: 'M', email: 'pastor3@conecta.com', congIdx: 2 },
];

const supervisores = [
  { name: 'Carlos Mendes', gender: 'M', email: 'supervisor1@conecta.com', congIdx: 0, supIdx: 0 },
  { name: 'Fernanda Ribeiro', gender: 'F', email: 'supervisor2@conecta.com', congIdx: 0, supIdx: 1 },
  { name: 'Thiago Souza', gender: 'M', email: 'supervisor3@conecta.com', congIdx: 1, supIdx: 2 },
  { name: 'Patrícia Costa', gender: 'F', email: 'supervisor4@conecta.com', congIdx: 1, supIdx: 3 },
  { name: 'André Nascimento', gender: 'M', email: 'supervisor5@conecta.com', congIdx: 2, supIdx: 4 },
  { name: 'Juliana Campos', gender: 'F', email: 'supervisor6@conecta.com', congIdx: 2, supIdx: 5 },
];

const lideres = [
  // Supervisão Alpha (Igreja Central) — 4 células
  { name: 'Ana Paula Silva', gender: 'F', email: 'lider1@conecta.com' },
  { name: 'Bruno Teixeira', gender: 'M', email: 'lider2@conecta.com' },
  { name: 'Gabriela Rocha', gender: 'F', email: 'lider3@conecta.com' },
  { name: 'Felipe Moreira', gender: 'M', email: 'lider4@conecta.com' },
  // Supervisão Beta (Igreja Central) — 4 células
  { name: 'Camila Batista', gender: 'F', email: 'lider5@conecta.com' },
  { name: 'Lucas Pinto', gender: 'M', email: 'lider6@conecta.com' },
  { name: 'Renata Vieira', gender: 'F', email: 'lider7@conecta.com' },
  { name: 'Diego Araújo', gender: 'M', email: 'lider8@conecta.com' },
  // Supervisão Gama (Igreja Norte) — 4 células
  { name: 'Isabela Gomes', gender: 'F', email: 'lider9@conecta.com' },
  { name: 'Rafael Barbosa', gender: 'M', email: 'lider10@conecta.com' },
  { name: 'Tatiane Cardoso', gender: 'F', email: 'lider11@conecta.com' },
  { name: 'Henrique Lopes', gender: 'M', email: 'lider12@conecta.com' },
  // Supervisão Delta (Igreja Norte) — 4 células
  { name: 'Michele Freitas', gender: 'F', email: 'lider13@conecta.com' },
  { name: 'Samuel Machado', gender: 'M', email: 'lider14@conecta.com' },
  { name: 'Olivia Duarte', gender: 'F', email: 'lider15@conecta.com' },
  { name: 'Pedro Castro', gender: 'M', email: 'lider16@conecta.com' },
  // Supervisão Epsilon (Igreja Sul) — 4 células
  { name: 'Sara Correia', gender: 'F', email: 'lider17@conecta.com' },
  { name: 'Gustavo Nunes', gender: 'M', email: 'lider18@conecta.com' },
  { name: 'Eduarda Melo', gender: 'F', email: 'lider19@conecta.com' },
  { name: 'Leonardo Brito', gender: 'M', email: 'lider20@conecta.com' },
  // Supervisão Zeta (Igreja Sul) — 4 células
  { name: 'Priscila Ramos', gender: 'F', email: 'lider21@conecta.com' },
  { name: 'Vinícius Fonseca', gender: 'M', email: 'lider22@conecta.com' },
  { name: 'Beatriz Moura', gender: 'F', email: 'lider23@conecta.com' },
  { name: 'Mateus Azevedo', gender: 'M', email: 'lider24@conecta.com' },
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
// Reserve pre-assigned names
for (const p of pastores) usedNames.add(p.name);
for (const s of supervisores) usedNames.add(s.name);
for (const l of lideres) usedNames.add(l.name);

function gerarNomeUnico(gender) {
  const g = gender || pick(['M', 'F']);
  const firstNames = g === 'M' ? primeirosNomesMasc : primeirosNomesFem;
  let name, attempts = 0;
  do {
    const first = pick(firstNames);
    const last = pick(sobrenomes);
    name = attempts > 300
      ? `${first} ${String.fromCharCode(65 + rand(0, 25))}. ${last}`
      : `${first} ${last}`;
    attempts++;
  } while (usedNames.has(name));
  usedNames.add(name);
  return { name, gender: g };
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
  if (snap.size === 0) {
    console.log(`  · '${nome}' já vazio`);
    return;
  }

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
  const auth = getAuth(app);
  const db = getFirestore(app);

  const PASSWORD = '123456';

  // ═════════════════════════════════════════
  //  FASE 0: LIMPEZA TOTAL
  // ═════════════════════════════════════════
  console.log('\n══════════════════════════════════════');
  console.log('  FASE 0 — LIMPANDO TUDO');
  console.log('══════════════════════════════════════\n');

  const colecoes = [
    'meetings', 'member_history', 'approval_requests',
    'cell_members', 'members', 'people',
    'cells', 'supervisions', 'congregations', 'users',
  ];
  for (const col of colecoes) {
    await limparColecao(db, col);
  }

  // ═════════════════════════════════════════
  //  FASE 1: CONGREGAÇÕES (sem pastor)
  // ═════════════════════════════════════════
  console.log('\n══════════════════════════════════════');
  console.log('  FASE 1 — CONGREGAÇÕES');
  console.log('══════════════════════════════════════\n');

  const congregacoes = [];
  for (let i = 0; i < 3; i++) {
    const ref = await addDoc(collection(db, 'congregations'), {
      name: nomesCongregacoes[i],
      pastorId: null,
      pastorName: null,
    });
    congregacoes.push({ id: ref.id, name: nomesCongregacoes[i] });
    console.log(`  📍 ${nomesCongregacoes[i]} (${ref.id})`);
  }

  // ═════════════════════════════════════════
  //  FASE 2: PESSOAS (todos os membros da igreja)
  // ═════════════════════════════════════════
  console.log('\n══════════════════════════════════════');
  console.log('  FASE 2 — PESSOAS');
  console.log('══════════════════════════════════════\n');

  // personMap: name → { personId, congIdx, role, ... }
  const personMap = new Map();
  let batch = writeBatch(db);
  let batchCount = 0;

  async function flushBatch() {
    if (batchCount > 0) {
      await batch.commit();
      batch = writeBatch(db);
      batchCount = 0;
    }
  }

  async function addPerson(name, gender, congIdx, phone) {
    const personRef = doc(collection(db, 'people'));
    const birthDate = gerarDataNascimento();
    batch.set(personRef, {
      name,
      phone: phone || gerarTelefone(),
      gender,
      baptized: true,
      birthDate: Timestamp.fromDate(birthDate),
      email: null,
      congregationId: congregacoes[congIdx].id,
      userId: null,
    });
    batchCount++;
    if (batchCount >= 400) await flushBatch();
    return personRef.id;
  }

  // 2a. Pastores (3)
  console.log('  Pastores:');
  for (const p of pastores) {
    const personId = await addPerson(p.name, p.gender, p.congIdx);
    personMap.set(p.name, { personId, congIdx: p.congIdx, role: 'pastor', email: p.email });
    console.log(`    ✓ Pr. ${p.name} → ${nomesCongregacoes[p.congIdx]}`);
  }

  // 2b. Supervisores (6)
  console.log('  Supervisores:');
  for (const s of supervisores) {
    const personId = await addPerson(s.name, s.gender, s.congIdx);
    personMap.set(s.name, { personId, congIdx: s.congIdx, supIdx: s.supIdx, role: 'supervisor', email: s.email });
    console.log(`    ✓ ${s.name} → Supervisão ${nomesSupervisoes[s.supIdx]}`);
  }

  // 2c. Líderes (24)
  // Each leader belongs to a supervision. Supervisions 0-1 → cong 0, 2-3 → cong 1, 4-5 → cong 2
  console.log('  Líderes:');
  for (let i = 0; i < lideres.length; i++) {
    const l = lideres[i];
    const supIdx = Math.floor(i / 4); // 0-3 → sup0, 4-7 → sup1, etc.
    const congIdx = Math.floor(supIdx / 2); // 0-1 → cong0, 2-3 → cong1, 4-5 → cong2
    const personId = await addPerson(l.name, l.gender, congIdx);
    personMap.set(l.name, { personId, congIdx, supIdx, cellIdx: i, role: 'leader', email: l.email });
  }
  console.log(`    ✓ ${lideres.length} líderes criados`);

  // 2d. Membros regulares (3-5 por célula = 72-120)
  console.log('  Membros:');
  const membersPerCell = []; // array of arrays, index = cellIdx
  let totalMembers = 0;

  for (let cellIdx = 0; cellIdx < 24; cellIdx++) {
    const supIdx = Math.floor(cellIdx / 4);
    const congIdx = Math.floor(supIdx / 2);
    const numMembers = rand(3, 5);
    const cellMembers = [];

    for (let m = 0; m < numMembers; m++) {
      const { name, gender } = gerarNomeUnico();
      const personId = await addPerson(name, gender, congIdx);
      cellMembers.push({ name, personId, gender });
      totalMembers++;
    }
    membersPerCell.push(cellMembers);
  }
  await flushBatch();
  console.log(`    ✓ ${totalMembers} membros criados`);
  console.log(`  Total: ${personMap.size + totalMembers} pessoas`);

  // ═════════════════════════════════════════
  //  FASE 3: SUPERVISÕES (sem supervisor)
  // ═════════════════════════════════════════
  console.log('\n══════════════════════════════════════');
  console.log('  FASE 3 — SUPERVISÕES');
  console.log('══════════════════════════════════════\n');

  const supervisoesDb = [];
  for (let i = 0; i < 6; i++) {
    const congIdx = Math.floor(i / 2);
    const ref = await addDoc(collection(db, 'supervisions'), {
      name: `Supervisão ${nomesSupervisoes[i]}`,
      congregationId: congregacoes[congIdx].id,
      supervisorId: null,
      supervisorName: null,
    });
    supervisoesDb.push({ id: ref.id, name: nomesSupervisoes[i], congIdx });
    console.log(`  🔷 Supervisão ${nomesSupervisoes[i]} → ${nomesCongregacoes[congIdx]} (${ref.id})`);
  }

  // ═════════════════════════════════════════
  //  FASE 4: CÉLULAS (sem líder)
  // ═════════════════════════════════════════
  console.log('\n══════════════════════════════════════');
  console.log('  FASE 4 — CÉLULAS');
  console.log('══════════════════════════════════════\n');

  const shuffledCellNames = shuffle(nomesCelulas);
  const celulasDb = [];

  for (let i = 0; i < 24; i++) {
    const supIdx = Math.floor(i / 4);
    const sup = supervisoesDb[supIdx];
    const cellName = `Célula ${shuffledCellNames[i]}`;
    const ref = await addDoc(collection(db, 'cells'), {
      name: cellName,
      supervisionId: sup.id,
      congregationId: congregacoes[sup.congIdx].id,
      leaderId: null,
      leaderName: null,
      meetingDay: pick(diasSemana),
      meetingTime: `${rand(18, 20)}:${pick(['00', '30'])}`,
      address: gerarEndereco(),
    });
    celulasDb.push({ id: ref.id, name: cellName, supIdx, congIdx: sup.congIdx });
  }

  // Print grouped by supervision
  for (let si = 0; si < 6; si++) {
    console.log(`  Supervisão ${nomesSupervisoes[si]}:`);
    for (let ci = si * 4; ci < (si + 1) * 4; ci++) {
      console.log(`    🟢 ${celulasDb[ci].name} (${celulasDb[ci].id})`);
    }
  }

  // ═════════════════════════════════════════
  //  FASE 5: CELL MEMBERS (vincula pessoa ↔ célula)
  // ═════════════════════════════════════════
  console.log('\n══════════════════════════════════════');
  console.log('  FASE 5 — CELL MEMBERS');
  console.log('══════════════════════════════════════\n');

  let totalCellMembers = 0;

  for (let cellIdx = 0; cellIdx < 24; cellIdx++) {
    const cell = celulasDb[cellIdx];
    const sup = supervisoesDb[cell.supIdx];
    const congId = congregacoes[cell.congIdx].id;
    const leader = lideres[cellIdx];
    const leaderData = personMap.get(leader.name);

    // Líder como cell_member
    const leaderCmRef = doc(collection(db, 'cell_members'));
    batch.set(leaderCmRef, {
      personId: leaderData.personId,
      personName: leader.name,
      cellId: cell.id,
      supervisionId: sup.id,
      congregationId: congId,
      isLeader: true,
      isHelper: false,
      isVisitor: false,
      isActive: true,
    });
    batchCount++;
    totalCellMembers++;

    // Membros regulares como cell_members
    for (const member of membersPerCell[cellIdx]) {
      const cmRef = doc(collection(db, 'cell_members'));
      batch.set(cmRef, {
        personId: member.personId,
        personName: member.name,
        cellId: cell.id,
        supervisionId: sup.id,
        congregationId: congId,
        isLeader: false,
        isHelper: false,
        isVisitor: false,
        isActive: true,
      });
      batchCount++;
      totalCellMembers++;

      if (batchCount >= 400) await flushBatch();
    }
  }
  await flushBatch();
  console.log(`  ✓ ${totalCellMembers} cell_members criados (24 líderes + ${totalCellMembers - 24} membros)`);

  // ═════════════════════════════════════════
  //  FASE 6: AUTH USERS (logins)
  // ═════════════════════════════════════════
  console.log('\n══════════════════════════════════════');
  console.log('  FASE 6 — LOGINS (Firebase Auth)');
  console.log('══════════════════════════════════════\n');

  async function criarOuReusar(email, password) {
    try {
      const cred = await createUserWithEmailAndPassword(auth, email, password);
      return cred.user.uid;
    } catch (err) {
      if (err.code === 'auth/email-already-in-use') {
        const cred = await signInWithEmailAndPassword(auth, email, password);
        return cred.user.uid;
      }
      throw err;
    }
  }

  const userMap = new Map(); // email → uid

  // Admin
  const adminUid = await criarOuReusar('admin@conecta.com', PASSWORD);
  await setDoc(doc(db, 'users', adminUid), {
    name: 'Caio Admin',
    email: 'admin@conecta.com',
    role: 'admin',
    congregationId: congregacoes[0].id,
    supervisionId: null,
    cellId: null,
  });
  userMap.set('admin@conecta.com', adminUid);
  console.log(`  ✓ admin      | admin@conecta.com`);

  // Pastores
  for (const p of pastores) {
    const uid = await criarOuReusar(p.email, PASSWORD);
    await setDoc(doc(db, 'users', uid), {
      name: `Pr. ${p.name}`,
      email: p.email,
      role: 'pastor',
      congregationId: congregacoes[p.congIdx].id,
      supervisionId: null,
      cellId: null,
    });
    userMap.set(p.email, uid);
    // Link person → userId
    const pData = personMap.get(p.name);
    await setDoc(doc(db, 'people', pData.personId), { userId: uid }, { merge: true });
    console.log(`  ✓ pastor     | ${p.email.padEnd(25)} | Pr. ${p.name} → ${nomesCongregacoes[p.congIdx]}`);
  }

  // Supervisores
  for (const s of supervisores) {
    const uid = await criarOuReusar(s.email, PASSWORD);
    await setDoc(doc(db, 'users', uid), {
      name: s.name,
      email: s.email,
      role: 'supervisor',
      congregationId: congregacoes[s.congIdx].id,
      supervisionId: supervisoesDb[s.supIdx].id,
      cellId: null,
    });
    userMap.set(s.email, uid);
    const sData = personMap.get(s.name);
    await setDoc(doc(db, 'people', sData.personId), { userId: uid }, { merge: true });
    console.log(`  ✓ supervisor | ${s.email.padEnd(25)} | ${s.name} → Sup. ${nomesSupervisoes[s.supIdx]}`);
  }

  // Líderes
  for (let i = 0; i < lideres.length; i++) {
    const l = lideres[i];
    const lData = personMap.get(l.name);
    const cell = celulasDb[i];
    const uid = await criarOuReusar(l.email, PASSWORD);
    await setDoc(doc(db, 'users', uid), {
      name: l.name,
      email: l.email,
      role: 'leader',
      congregationId: congregacoes[lData.congIdx].id,
      supervisionId: supervisoesDb[lData.supIdx].id,
      cellId: cell.id,
    });
    userMap.set(l.email, uid);
    await setDoc(doc(db, 'people', lData.personId), { userId: uid }, { merge: true });
  }
  console.log(`  ✓ ${lideres.length} líderes criados`);

  // ═════════════════════════════════════════
  //  FASE 7: ATUALIZA REFERÊNCIAS CRUZADAS
  // ═════════════════════════════════════════
  console.log('\n══════════════════════════════════════');
  console.log('  FASE 7 — REFERÊNCIAS CRUZADAS');
  console.log('══════════════════════════════════════\n');

  // Congregation → pastorId/pastorName
  for (const p of pastores) {
    const uid = userMap.get(p.email);
    await setDoc(doc(db, 'congregations', congregacoes[p.congIdx].id), {
      pastorId: uid,
      pastorName: `Pr. ${p.name}`,
    }, { merge: true });
    console.log(`  📍 ${nomesCongregacoes[p.congIdx]} → Pr. ${p.name}`);
  }

  // Supervision → supervisorId/supervisorName
  for (const s of supervisores) {
    const uid = userMap.get(s.email);
    await setDoc(doc(db, 'supervisions', supervisoesDb[s.supIdx].id), {
      supervisorId: uid,
      supervisorName: s.name,
    }, { merge: true });
    console.log(`  🔷 Supervisão ${nomesSupervisoes[s.supIdx]} → ${s.name}`);
  }

  // Cell → leaderId/leaderName
  for (let i = 0; i < lideres.length; i++) {
    const l = lideres[i];
    const uid = userMap.get(l.email);
    const cell = celulasDb[i];
    await setDoc(doc(db, 'cells', cell.id), {
      leaderId: uid,
      leaderName: l.name,
    }, { merge: true });
  }
  console.log(`  🟢 ${lideres.length} células vinculadas aos líderes`);

  // ═════════════════════════════════════════
  //  RESUMO FINAL
  // ═════════════════════════════════════════
  console.log('\n══════════════════════════════════════');
  console.log('  RESUMO FINAL');
  console.log('══════════════════════════════════════\n');

  console.log(`  📍  ${congregacoes.length} Congregações`);
  console.log(`  🔷  ${supervisoesDb.length} Supervisões (4 células cada)`);
  console.log(`  🟢  ${celulasDb.length} Células`);
  console.log(`  👤  ${personMap.size + totalMembers} Pessoas`);
  console.log(`  🔗  ${totalCellMembers} Cell Members`);
  console.log(`  🔑  ${userMap.size} Logins`);

  console.log('\n  ── LOGINS (senha: 123456) ──\n');
  console.log(`    admin       admin@conecta.com`);
  for (const p of pastores) {
    console.log(`    pastor      ${p.email.padEnd(25)}  Pr. ${p.name} → ${nomesCongregacoes[p.congIdx]}`);
  }
  for (const s of supervisores) {
    console.log(`    supervisor  ${s.email.padEnd(25)}  ${s.name} → Sup. ${nomesSupervisoes[s.supIdx]}`);
  }
  for (let i = 0; i < lideres.length; i++) {
    const l = lideres[i];
    console.log(`    lider       ${l.email.padEnd(25)}  ${l.name} → ${celulasDb[i].name}`);
  }

  console.log('\n  ── HIERARQUIA ──\n');
  for (let ci = 0; ci < 3; ci++) {
    const pastor = pastores[ci];
    console.log(`  ${nomesCongregacoes[ci]} (Pr. ${pastor.name})`);
    for (let si = ci * 2; si < ci * 2 + 2; si++) {
      const sup = supervisores.find(s => s.supIdx === si);
      console.log(`    └─ Supervisão ${nomesSupervisoes[si]} (${sup.name})`);
      for (let celli = si * 4; celli < si * 4 + 4; celli++) {
        const cell = celulasDb[celli];
        const leader = lideres[celli];
        const members = membersPerCell[celli];
        const marker = celli === si * 4 + 3 ? '└─' : '├─';
        console.log(`       ${marker} ${cell.name} — ${leader.name} (${members.length + 1} membros)`);
      }
    }
    console.log('');
  }

  console.log('══════════════════════════════════════');
  console.log('  PRONTO! Hot restart no app pra ver.');
  console.log('══════════════════════════════════════\n');

  process.exit(0);
}

main().catch(err => {
  console.error('\n❌ ERRO:', err);
  process.exit(1);
});
