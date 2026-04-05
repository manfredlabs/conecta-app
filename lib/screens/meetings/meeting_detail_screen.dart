import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cell_provider.dart';
import '../../models/meeting_model.dart';

class MeetingDetailScreen extends StatelessWidget {
  const MeetingDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final meeting = ModalRoute.of(context)!.settings.arguments as Meeting;
    final members = context.watch<CellProvider>().members;

    final dateStr =
        '${meeting.date.day.toString().padLeft(2, '0')}/${meeting.date.month.toString().padLeft(2, '0')}/${meeting.date.year}';

    // Map member IDs to names
    final presentMembers = members
        .where((m) => meeting.presentMemberIds.contains(m.id))
        .toList();
    final absentMembers = members
        .where((m) => !meeting.presentMemberIds.contains(m.id))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text('Reunião $dateStr')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      icon: Icons.people,
                      value: '${presentMembers.length}',
                      label: 'Presentes',
                      color: Colors.green,
                    ),
                    _StatItem(
                      icon: Icons.person_off,
                      value: '${absentMembers.length}',
                      label: 'Ausentes',
                      color: Colors.red,
                    ),
                    _StatItem(
                      icon: Icons.person_add,
                      value: '${meeting.visitors.length}',
                      label: 'Visitantes',
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Present members
            if (presentMembers.isNotEmpty) ...[
              Text(
                'Presentes (${presentMembers.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
              ),
              const SizedBox(height: 8),
              ...presentMembers.map((m) => Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      leading: const Icon(Icons.check_circle,
                          color: Colors.green),
                      title: Text(m.name),
                    ),
                  )),
            ],

            const SizedBox(height: 16),

            // Absent members
            if (absentMembers.isNotEmpty) ...[
              Text(
                'Ausentes (${absentMembers.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
              ),
              const SizedBox(height: 8),
              ...absentMembers.map((m) => Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      leading:
                          const Icon(Icons.cancel, color: Colors.red),
                      title: Text(m.name),
                    ),
                  )),
            ],

            const SizedBox(height: 16),

            // Visitors
            if (meeting.visitors.isNotEmpty) ...[
              Text(
                'Visitantes (${meeting.visitors.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
              ),
              const SizedBox(height: 8),
              ...meeting.visitors.map((v) => Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      leading: const Icon(Icons.person_outline,
                          color: Colors.blue),
                      title: Text(v.name),
                      subtitle: v.phone != null ? Text(v.phone!) : null,
                    ),
                  )),
            ],

            // Observations
            if (meeting.observations != null &&
                meeting.observations!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Observações',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(meeting.observations!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }
}
