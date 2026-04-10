// Seed script para eventos da igreja (Agenda)
// Uso: node scripts/seed_events.js

const { initializeApp } = require('firebase/app');
const { getFirestore, collection, addDoc, Timestamp } = require('firebase/firestore');

const firebaseConfig = {
  apiKey: "AIzaSyDXqjSPCqL9od9v7CUmw3CeFasXYuZ_fzE",
  authDomain: "conecta-64c31.firebaseapp.com",
  projectId: "conecta-64c31",
  storageBucket: "conecta-64c31.firebasestorage.app",
  messagingSenderId: "136498499498",
  appId: "1:136498499498:web:2cee46a06ac2d28c9fbcd8"
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

const churchId = 'gdfJ2ryG71YqUDHybQEj';

async function seed() {
  const events = [
    {
      title: 'Culto de Adoração',
      dateTime: new Date(2026, 3, 12, 19, 0),  // 12/04/2026 19h
      location: 'Templo Central',
      description: 'Culto especial de adoração com participação do coral.',
      churchId,
      createdBy: 'seed',
      createdAt: new Date(),
    },
    {
      title: 'Encontro de Líderes',
      dateTime: new Date(2026, 3, 14, 20, 0),  // 14/04/2026 20h
      location: 'Sala de reuniões',
      description: 'Reunião mensal de líderes de célula. Pauta: planejamento do mês de maio.',
      churchId,
      createdBy: 'seed',
      createdAt: new Date(),
    },
    {
      title: 'Noite de Louvor',
      dateTime: new Date(2026, 3, 18, 19, 30),  // 18/04/2026 19:30
      location: 'Templo Central',
      description: '',
      churchId,
      createdBy: 'seed',
      createdAt: new Date(),
    },
    {
      title: 'Retiro Espiritual',
      dateTime: new Date(2026, 3, 25, 8, 0),  // 25/04/2026 08h
      location: 'Sítio Paz e Amor',
      description: 'Retiro de final de semana. Levar roupa de cama e toalha.',
      churchId,
      createdBy: 'seed',
      createdAt: new Date(),
    },
    {
      title: 'Estudo Bíblico',
      dateTime: new Date(2026, 3, 10, 20, 0),  // 10/04/2026 20h (hoje)
      location: 'Templo Central',
      description: 'Estudo do livro de Romanos, capítulo 8.',
      churchId,
      createdBy: 'seed',
      createdAt: new Date(),
    },
  ];

  for (const event of events) {
    const data = {
      ...event,
      dateTime: Timestamp.fromDate(event.dateTime),
      createdAt: Timestamp.fromDate(event.createdAt),
    };
    const ref = await addDoc(collection(db, 'events'), data);
    console.log(`✓ ${event.title} → ${ref.id}`);
  }

  console.log('\nDone! 5 eventos criados.');
  process.exit(0);
}

seed().catch(console.error);
