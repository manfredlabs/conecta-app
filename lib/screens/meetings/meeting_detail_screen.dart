import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cell_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/permissions.dart';
import '../../models/meeting_model.dart';
import '../../models/cell_member_model.dart';

class MeetingDetailScreen extends StatelessWidget {
  const MeetingDetailScreen({super.key});

  void _confirmDelete(BuildContext context, Meeting meeting) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.delete_outline_rounded,
                  size: 28, color: Colors.red[400]),
            ),
            const SizedBox(height: 16),
            Text(
              'Excluir esta reunião?',
              style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Essa ação não pode ser desfeita.',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red[400],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _roleLabel(CellMember m) {
    if (m.isLeader) return 'Líder';
    if (m.isHelper) return 'Auxiliar';
    if (m.isVisitor) return 'Visitante';
    return 'Membro';
  }

  String _snapshotRoleLabel(String role) {
    switch (role) {
      case 'leader':
        return 'Líder';
      case 'helper':
        return 'Auxiliar';
      case 'visitor':
        return 'Visitante';
      default:
        return 'Membro';
    }
  }

  Color _roleColor(CellMember m, ThemeData theme) {
    return Colors.grey[600]!;
  }

  @override
  Widget build(BuildContext context) {
    final argMeeting = ModalRoute.of(context)!.settings.arguments as Meeting;
    final cellProvider = context.watch<CellProvider>();
    final user = context.read<AuthProvider>().appUser;
    final cell = cellProvider.selectedCell;
    final allMembers = cellProvider.cellMembers;
    final theme = Theme.of(context);
    final canEdit =
        user != null && cell != null && Permissions.canEditMeeting(user, cell);

    final meeting = cellProvider.meetings
            .where((m) => m.id == argMeeting.id)
            .firstOrNull ??
        argMeeting;

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
    int sortByRole(CellMember a, CellMember b) {
      int priority(String role) {
        switch (role) {
          case 'leader': return 0;
          case 'helper': return 1;
          case 'visitor': return 3;
          default: return 2;
        }
      }
      int currentPriority(CellMember m) =>
          m.isLeader ? 0 : m.isHelper ? 1 : m.isVisitor ? 3 : 2;

      final pa = meeting.memberRoles.containsKey(a.id)
          ? priority(meeting.memberRoles[a.id]!)
          : currentPriority(a);
      final pb = meeting.memberRoles.containsKey(b.id)
          ? priority(meeting.memberRoles[b.id]!)
          : currentPriority(b);
      final p = pa.compareTo(pb);
      if (p != 0) return p;
      return a.name.compareTo(b.name);
    }

    final presentMembers = allMembers
        .where((m) => meeting.presentMemberIds.contains(m.id))
        .toList()
      ..sort(sortByRole);

    // Absent = non-visitor members from snapshot who weren't present
    final List<CellMember> absentMembers;
    if (meeting.memberRoles.isNotEmpty) {
      final nonVisitorIds = meeting.memberRoles.entries
          .where((e) => e.value != 'visitor')
          .map((e) => e.key)
          .toSet();
      absentMembers = allMembers
          .where((m) =>
              nonVisitorIds.contains(m.id) &&
              !meeting.presentMemberIds.contains(m.id))
          .toList()
        ..sort(sortByRole);
    } else {
      absentMembers = activeMembers
          .where(
              (m) => !meeting.presentMemberIds.contains(m.id) && !m.isVisitor)
          .toList()
        ..sort(sortByRole);
    }

    return Scaffold(
      appBar: AppBar(title: Text('$weekday, $dateStr')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Summary badges
          Row(
            children: [
              _Badge(
                  label: '${presentMembers.length} presentes',
                  color: Colors.green[600]!),
              const SizedBox(width: 8),
              _Badge(
                  label: '${absentMembers.length} ausentes',
                  color: Colors.red[400]!),
            ],
          ),

          const SizedBox(height: 20),

          // ── Presentes ──
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
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0; i < presentMembers.length; i++) ...[
                    _MemberRow(
                      name: presentMembers[i].name,
                      role: meeting.memberRoles.containsKey(presentMembers[i].id)
                          ? _snapshotRoleLabel(meeting.memberRoles[presentMembers[i].id]!)
                          : _roleLabel(presentMembers[i]),
                      roleColor: _roleColor(presentMembers[i], theme),
                      isPresent: true,
                    ),
                    if (i < presentMembers.length - 1)
                      Divider(
                          height: 1,
                          indent: 56,
                          color: Colors.grey[100]),
                  ],
                ],
              ),
            ),
          ],

          if (presentMembers.isNotEmpty && absentMembers.isNotEmpty)
            const SizedBox(height: 20),

          // ── Ausentes ──
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
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0; i < absentMembers.length; i++) ...[
                    _MemberRow(
                      name: absentMembers[i].name,
                      role: meeting.memberRoles.containsKey(absentMembers[i].id)
                          ? _snapshotRoleLabel(meeting.memberRoles[absentMembers[i].id]!)
                          : _roleLabel(absentMembers[i]),
                      roleColor: _roleColor(absentMembers[i], theme),
                      isPresent: false,
                    ),
                    if (i < absentMembers.length - 1)
                      Divider(
                          height: 1,
                          indent: 56,
                          color: Colors.grey[100]),
                  ],
                ],
              ),
            ),
          ],

          // ── Observações ──
          if (meeting.observations != null &&
              meeting.observations!.isNotEmpty) ...[
            const SizedBox(height: 20),
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

          // ── Ações ──
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
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final String name;
  final String role;
  final Color roleColor;
  final bool isPresent;

  const _MemberRow({
    required this.name,
    required this.role,
    required this.roleColor,
    required this.isPresent,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPresent ? roleColor : Colors.grey;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: isPresent ? roleColor : Colors.grey[400],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isPresent ? null : Colors.grey[400],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              role,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isPresent ? roleColor : Colors.grey[400],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
