// Script para gerar reuniões fictícias para todas as células
// Rode com: node seed_meetings.js

const { initializeApp } = require('firebase/app');
const { getFirestore, collection, addDoc, getDocs, query, where, Timestamp } = require('firebase/firestore');
const fs = require('fs');
const path = require('path');

function rand(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

const observacoes = [
  'Reunião abençoada, todos participaram do louvor.',
  'Estudo sobre Romanos 8. Muito edificante.',
  'Célula com bastante visitante hoje!',
  'Compartilhamos testemunhos. Momento muito especial.',
  'Fizemos oração pelos enfermos.',
  'Noite de louvor e adoração.',
  'Estudo do livro de Provérbios.',
  'Muita comunhão e alegria.',
  'Palavra sobre fé e perseverança.',
  'Célula no formato de jantar. Ótima integração.',
  'Oramos por cada família presente.',
  'Noite de testemunhos e gratidão.',
  null, null, null, // ~20% sem observação
];

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

  console.log('\n=== Gerando reuniões fictícias ===\n');

  // Buscar todas as células
  const cellsSnap = await getDocs(collection(db, 'cells'));
  const cells = cellsSnap.docs.map(d => ({ id: d.id, ...d.data() }));
  console.log(`Encontradas ${cells.length} células\n`);

  let totalMeetings = 0;

  for (const cell of cells) {
    // Buscar membros desta célula
    const membersQuery = query(collection(db, 'members'), where('cellId', '==', cell.id));
    const membersSnap = await getDocs(membersQuery);
    const memberIds = membersSnap.docs.map(d => d.id);

    if (memberIds.length === 0) continue;

    // Gerar entre 3 e 8 reuniões nas últimas semanas
    const numMeetings = rand(3, 8);

    for (let i = 0; i < numMeetings; i++) {
      // Data: entre 1 e 60 dias atrás
      const daysAgo = rand(1, 60);
      const meetingDate = new Date();
      meetingDate.setDate(meetingDate.getDate() - daysAgo);
      meetingDate.setHours(19, 30, 0, 0);

      // Presença: entre 50% e 100% dos membros
      const minPresent = Math.max(1, Math.floor(memberIds.length * 0.5));
      const numPresent = rand(minPresent, memberIds.length);
      const shuffled = [...memberIds].sort(() => Math.random() - 0.5);
      const presentIds = shuffled.slice(0, numPresent);

      // Visitantes: 0-3 por reunião (30% chance de ter)
      const visitors = [];
      if (Math.random() < 0.3) {
        const numVisitors = rand(1, 3);
        const nomesVisitantes = [
          'Maria', 'José', 'Pedro', 'Luiza', 'Carlos', 'Joana',
          'Ricardo', 'Letícia', 'Marcos', 'Bianca', 'Rafael', 'Aline',
        ];
        for (let v = 0; v < numVisitors; v++) {
          visitors.push({
            name: pick(nomesVisitantes),
            phone: Math.random() > 0.5 ? `119${rand(10000000, 99999999)}` : null,
          });
        }
      }

      await addDoc(collection(db, 'meetings'), {
        cellId: cell.id,
        supervisionId: cell.supervisionId,
        congregationId: cell.congregationId,
        date: Timestamp.fromDate(meetingDate),
        presentMemberIds: presentIds,
        visitors: visitors,
        observations: pick(observacoes),
        createdBy: cell.leaderId || 'system',
      });
      totalMeetings++;
    }

    console.log(`  ✅ ${cell.name} — ${numMeetings} reuniões`);
  }

  console.log(`\n=== Resumo ===`);
  console.log(`  Total de reuniões criadas: ${totalMeetings}`);
  console.log(`\n✅ Reuniões geradas com sucesso!\n`);

  process.exit(0);
}

main().catch(console.error);
