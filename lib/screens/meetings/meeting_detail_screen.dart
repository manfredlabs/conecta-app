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

  Color _roleColor(CellMember m, ThemeData theme) {
    if (m.isLeader) return theme.colorScheme.primary;
    if (m.isHelper) return Colors.teal;
    if (m.isVisitor) return Colors.orange;
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
    final primaryColor = theme.colorScheme.primary;
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
      int priority(CellMember m) =>
          m.isLeader ? 0 : m.isHelper ? 1 : m.isVisitor ? 3 : 2;
      final p = priority(a).compareTo(priority(b));
      if (p != 0) return p;
      return a.name.compareTo(b.name);
    }

    final presentMembers = activeMembers
        .where((m) => meeting.presentMemberIds.contains(m.id))
        .toList()
      ..sort(sortByRole);
    final absentMembers = activeMembers
        .where(
            (m) => !meeting.presentMemberIds.contains(m.id) && !m.isVisitor)
        .toList()
      ..sort(sortByRole);
    final totalActive =
        activeMembers.where((m) => !m.isVisitor).length;
    final percentage = totalActive > 0
        ? ((presentMembers.where((m) => !m.isVisitor).length / totalActive) *
                100)
            .round()
        : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes da Reunião')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Header card ──
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.groups_outlined,
                        color: primaryColor, size: 28),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    weekday,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Stats row
                  Row(
                    children: [
                      Expanded(
                        child: _StatItem(
                          icon: Icons.check_circle_rounded,
                          iconColor: Colors.green[600]!,
                          value: '${presentMembers.length}',
                          label: 'Presentes',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey[200],
                      ),
                      Expanded(
                        child: _StatItem(
                          icon: Icons.cancel_rounded,
                          iconColor: Colors.red[400]!,
                          value: '${absentMembers.length}',
                          label: 'Ausentes',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey[200],
                      ),
                      Expanded(
                        child: _StatItem(
                          icon: Icons.pie_chart_rounded,
                          iconColor: primaryColor,
                          value: '$percentage%',
                          label: 'Frequência',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Presentes ──
          if (presentMembers.isNotEmpty) ...[
            _SectionHeader(
              title: 'Presentes',
              count: presentMembers.length,
              countColor: Colors.green[600]!,
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0; i < presentMembers.length; i++) ...[
                    _MemberRow(
                      name: presentMembers[i].name,
                      role: _roleLabel(presentMembers[i]),
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
            _SectionHeader(
              title: 'Ausentes',
              count: absentMembers.length,
              countColor: Colors.red[400]!,
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0; i < absentMembers.length; i++) ...[
                    _MemberRow(
                      name: absentMembers[i].name,
                      role: _roleLabel(absentMembers[i]),
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
            _SectionHeader(
              icon: Icons.notes_rounded,
              iconColor: Colors.grey[600]!,
              title: 'Observações',
            ),
            const SizedBox(height: 8),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.format_quote_rounded,
                        size: 20, color: Colors.grey[300]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        meeting.observations!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Ações ──
          if (canEdit) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Card(
                    margin: const EdgeInsets.only(right: 4),
                    color: primaryColor.withValues(alpha: 0.06),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/edit-meeting',
                        arguments: meeting,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 18, color: primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Editar',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
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
                    color: Colors.red.withValues(alpha: 0.06),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _confirmDelete(context, meeting),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 18, color: Colors.red[400]),
                            const SizedBox(width: 8),
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
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData? icon;
  final Color? iconColor;
  final Color? countColor;
  final String title;
  final int? count;

  const _SectionHeader({
    this.icon,
    this.iconColor,
    this.countColor,
    required this.title,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = countColor ?? iconColor ?? Colors.grey[600]!;
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ],
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isPresent ? null : Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
          ),
        ],
      ),
    );
  }
}
