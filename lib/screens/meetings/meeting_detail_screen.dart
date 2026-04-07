import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cell_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/permissions.dart';
import '../../models/meeting_model.dart';

class MeetingDetailScreen extends StatelessWidget {
  const MeetingDetailScreen({super.key});

  void _confirmDelete(BuildContext context, Meeting meeting) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, size: 48, color: Colors.red[400]),
            const SizedBox(height: 12),
            Text(
              'Excluir esta reunião?',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Essa ação não pode ser desfeita.',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () async {
                      final provider = context.read<CellProvider>();
                      Navigator.pop(ctx);
                      await provider.deleteMeeting(meeting.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Reunião excluída!')),
                        );
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Excluir'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final argMeeting = ModalRoute.of(context)!.settings.arguments as Meeting;
    final cellProvider = context.watch<CellProvider>();
    final user = context.read<AuthProvider>().appUser;
    final cell = cellProvider.selectedCell;
    final allMembers = cellProvider.cellMembers;
    final theme = Theme.of(context);
    final canEdit = user != null && cell != null && Permissions.canEditMeeting(user, cell);

    // Use updated meeting from provider if available (after edit)
    final meeting = cellProvider.meetings
        .where((m) => m.id == argMeeting.id)
        .firstOrNull ?? argMeeting;

    final weekdays = [
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo',
    ];
    final weekday = weekdays[meeting.date.weekday - 1];
    final dateStr =
        '${meeting.date.day.toString().padLeft(2, '0')}/${meeting.date.month.toString().padLeft(2, '0')}/${meeting.date.year}';

    final activeMembers = allMembers.where((m) => m.isActive).toList();
    int sortByRole(a, b) {
      int priority(m) => m.isLeader ? 0 : m.isHelper ? 1 : m.isVisitor ? 3 : 2;
      return priority(a).compareTo(priority(b));
    }

    final presentMembers = activeMembers
        .where((m) => meeting.presentMemberIds.contains(m.id))
        .toList()
      ..sort(sortByRole);
    final absentMembers = activeMembers
        .where((m) => !meeting.presentMemberIds.contains(m.id) && !m.isVisitor)
        .toList()
      ..sort(sortByRole);

    return Scaffold(
      appBar: AppBar(
        title: Text('$weekday, $dateStr'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Summary badges
          Row(
            children: [
              _Badge(label: '${presentMembers.length} presentes'),
              const SizedBox(width: 8),
              _Badge(label: '${absentMembers.length} ausentes'),
            ],
          ),

          const SizedBox(height: 20),

          // Presentes
          if (presentMembers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Presentes',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ...presentMembers.map((m) {
              final roleColor = m.isLeader
                  ? theme.colorScheme.primary
                  : m.isHelper
                      ? Colors.teal
                      : m.isVisitor
                          ? Colors.orange
                          : Colors.blue;
              return _MemberTile(
                  name: m.name,
                  role: m.isLeader
                      ? 'Líder'
                      : m.isHelper
                          ? 'Auxiliar'
                          : m.isVisitor
                              ? 'Visitante'
                              : 'Membro',
                  roleColor: roleColor,
              );
            }),
          ],

          if (presentMembers.isNotEmpty && absentMembers.isNotEmpty)
            const SizedBox(height: 16),

          // Ausentes
          if (absentMembers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Ausentes',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ...absentMembers.map((m) {
              final roleColor = m.isLeader
                  ? theme.colorScheme.primary
                  : m.isHelper
                      ? Colors.teal
                      : m.isVisitor
                          ? Colors.orange
                          : Colors.blue;
              return _MemberTile(
                  name: m.name,
                  role: m.isLeader
                      ? 'Líder'
                      : m.isHelper
                          ? 'Auxiliar'
                          : m.isVisitor
                              ? 'Visitante'
                              : 'Membro',
                  roleColor: roleColor,
              );
            }),
          ],

          // Observações
          if (meeting.observations != null &&
              meeting.observations!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Observações',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  meeting.observations!,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Ações
          if (canEdit)
          Row(
            children: [
              Expanded(
                child: Card(
                  margin: const EdgeInsets.only(right: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/edit-meeting',
                      arguments: meeting,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                            'Editar',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Card(
                  margin: const EdgeInsets.only(left: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _confirmDelete(context, meeting),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              size: 18, color: Colors.red[400]),
                          const SizedBox(width: 6),
                          Text(
                            'Excluir',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.red[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final String name;
  final String? role;
  final Color? roleColor;

  const _MemberTile({
    required this.name,
    this.role,
    this.roleColor,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = roleColor ?? Colors.grey;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.person_outline_rounded, color: Colors.grey[400], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            if (role != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  role!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
