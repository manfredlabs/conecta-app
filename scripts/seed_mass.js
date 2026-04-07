// Script para popular dados fictícios em massa no Firestore
// Rode com: node seed_mass.js

const { initializeApp } = require('firebase/app');
const { getFirestore, collection, addDoc, getDocs, deleteDoc, doc } = require('firebase/firestore');
const fs = require('fs');
const path = require('path');

// ─── Nomes realistas ───

const nomesCongregacoes = [
  'Congregação Central',
  'Congregação Monte Sião',
  'Congregação Ágape',
  'Congregação Nova Aliança',
  'Congregação Betel',
];

const nomesSupervisoes = [
  'Alpha', 'Beta', 'Gama', 'Delta', 'Epsilon', 'Zeta', 'Eta', 'Theta', 'Iota',
  'Kappa', 'Lambda', 'Sigma', 'Ômega', 'Rho', 'Phi', 'Psi', 'Chi', 'Tau', 'Upsilon',
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
];

const primeirosNomes = [
  'Ana', 'Bruno', 'Carla', 'Daniel', 'Eliane', 'Felipe', 'Gabriela', 'Hugo',
  'Isabela', 'João', 'Karen', 'Lucas', 'Mariana', 'Nicolas', 'Olivia', 'Paulo',
  'Rafaela', 'Samuel', 'Tatiane', 'Ulisses', 'Vanessa', 'Wagner', 'Yasmin', 'Zé',
  'Amanda', 'Breno', 'Camila', 'Diego', 'Eduarda', 'Fábio', 'Giovana', 'Henrique',
  'Ivana', 'Julio', 'Kátia', 'Leonardo', 'Michele', 'Natan', 'Patrícia', 'Roberto',
  'Sara', 'Thiago', 'Valéria', 'Wesley', 'Ximena', 'Renata', 'Pedro', 'Lúcia',
  'Marcos', 'Priscila', 'André', 'Beatriz', 'Cláudio', 'Débora', 'Estêvão', 'Fernanda',
  'Gustavo', 'Helena', 'Igor', 'Juliana', 'Kleber', 'Lorena', 'Mateus', 'Natália',
  'Otávio', 'Paloma', 'Raul', 'Simone', 'Tânia', 'Vinícius', 'Wanda', 'Yuri',
];

const sobrenomes = [
  'Silva', 'Santos', 'Oliveira', 'Souza', 'Costa', 'Pereira', 'Ferreira', 'Lima',
  'Almeida', 'Ribeiro', 'Rodrigues', 'Gomes', 'Martins', 'Araújo', 'Barbosa',
  'Carvalho', 'Nascimento', 'Mendes', 'Dias', 'Moura', 'Freitas', 'Cardoso',
  'Vieira', 'Rocha', 'Correia', 'Nunes', 'Monteiro', 'Teixeira', 'Pinto', 'Moreira',
  'Campos', 'Batista', 'Reis', 'Miranda', 'Lopes', 'Melo', 'Borges', 'Pires',
  'Machado', 'Castro', 'Duarte', 'Ramos', 'Cunha', 'Azevedo', 'Fonseca', 'Brito',
];

const diasSemana = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];

const pastores = [
  'Pr. Marcos Vieira', 'Pr. José Ribeiro', 'Pr. Paulo Mendes',
  'Pr. Ricardo Almeida', 'Pr. Antônio Freitas',
];

// ─── Helpers ───

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

function gerarNome() {
  return `${pick(primeirosNomes)} ${pick(sobrenomes)}`;
}

function gerarTelefone() {
  const ddd = pick(['11','21','31','41','51','61','71','81','85','27','48','47']);
  const num = `9${rand(1000,9999)}${rand(1000,9999)}`;
  return `${ddd}${num}`;
}

// ─── Limpar dados antigos ───

async function limparColecao(db, nome) {
  const snap = await getDocs(collection(db, nome));
  let count = 0;
  for (const d of snap.docs) {
    await deleteDoc(doc(db, nome, d.id));
    count++;
  }
  if (count > 0) console.log(`  Removidos ${count} docs de '${nome}'`);
}

// ─── Main ───

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

  console.log('\n=== Limpando dados antigos ===\n');
  for (const col of ['meetings', 'members', 'cells', 'supervisions', 'congregations']) {
    await limparColecao(db, col);
  }

  console.log('\n=== Gerando dados fictícios ===\n');

  const shuffledSupervisoes = shuffle(nomesSupervisoes);
  const shuffledCelulas = shuffle(nomesCelulas);
  let supIndex = 0;
  let celIndex = 0;

  let totalSup = 0, totalCel = 0, totalMem = 0;

  for (let c = 0; c < nomesCongregacoes.length; c++) {
    const congName = nomesCongregacoes[c];
    const pastorName = pastores[c];

    const congRef = await addDoc(collection(db, 'congregations'), {
      name: congName,
      pastorId: null,
      pastorName: pastorName,
    });
    console.log(`📍 ${congName} (${pastorName})`);

    const numSup = rand(3, 9);
    for (let s = 0; s < numSup; s++) {
      const supName = `Supervisão ${shuffledSupervisoes[supIndex % shuffledSupervisoes.length]}`;
      supIndex++;
      const supervisorName = gerarNome();

      const supRef = await addDoc(collection(db, 'supervisions'), {
        name: supName,
        congregationId: congRef.id,
        supervisorId: null,
        supervisorName: supervisorName,
      });
      totalSup++;
      console.log(`  🔷 ${supName} (${supervisorName})`);

      const numCel = rand(2, 10);
      for (let cl = 0; cl < numCel; cl++) {
        const celName = `Célula ${shuffledCelulas[celIndex % shuffledCelulas.length]}`;
        celIndex++;
        const leaderName = gerarNome();
        const dia = pick(diasSemana);

        const cellRef = await addDoc(collection(db, 'cells'), {
          name: celName,
          supervisionId: supRef.id,
          congregationId: congRef.id,
          leaderId: null,
          leaderName: leaderName,
          meetingDay: dia,
          address: null,
        });
        totalCel++;

        const numMem = rand(4, 12);
        const membrosUsados = new Set();
        for (let m = 0; m < numMem; m++) {
          let nome;
          do { nome = gerarNome(); } while (membrosUsados.has(nome));
          membrosUsados.add(nome);

          const temTelefone = Math.random() > 0.3;
          await addDoc(collection(db, 'members'), {
            name: nome,
            phone: temTelefone ? gerarTelefone() : null,
            cellId: cellRef.id,
            supervisionId: supRef.id,
            congregationId: congRef.id,
          });
          totalMem++;
        }
        console.log(`    🟢 ${celName} — ${leaderName} — ${numMem} membros (${dia})`);
      }
    }
    console.log('');
  }

  console.log('=== Resumo ===');
  console.log(`  Congregações: ${nomesCongregacoes.length}`);
  console.log(`  Supervisões:  ${totalSup}`);
  console.log(`  Células:      ${totalCel}`);
  console.log(`  Membros:      ${totalMem}`);
  console.log('\n✅ Dados criados com sucesso!\n');

  process.exit(0);
}

main().catch(console.error);
