import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cell_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/permissions.dart';

class CellHubScreen extends StatelessWidget {
  const CellHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Consumer<CellProvider>(
      builder: (context, cellProvider, _) {
        final cell = cellProvider.selectedCell;
        if (cell == null) {
          return const Scaffold(
            body: Center(child: Text('Nenhuma célula selecionada')),
          );
        }

        final members = cellProvider.cellMembers;
        final meetings = cellProvider.meetings;
        final activeCount = members.where((m) => m.isActive).length;
        final visitorCount =
            members.where((m) => m.isVisitor && m.isActive).length;
        final memberCount = activeCount - visitorCount;

        final user = context.read<AuthProvider>().appUser;
        final canEdit = user != null && Permissions.canEditCell(user, cell);
        final isOwnCell = user?.id == cell.leaderId;

        // Calcular dias desde última reunião
        int? lastMeetingDays;
        if (meetings.isNotEmpty) {
          final sorted = [...meetings]
            ..sort((a, b) => b.date.compareTo(a.date));
          lastMeetingDays =
              DateTime.now().difference(sorted.first.date).inDays;
        }

        // Montar subtítulo do schedule
        final scheduleItems = <String>[
          if (cell.meetingDay != null) cell.meetingDay!,
          if (cell.meetingTime != null) cell.meetingTime!,
        ];
        final scheduleText = scheduleItems.isNotEmpty
            ? scheduleItems.join(' · ')
            : null;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.10),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(Icons.groups_rounded,
                                      color: primaryColor, size: 26),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    cell.name,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (scheduleText != null)
                                  _HeaderChip(
                                    icon: Icons.schedule_rounded,
                                    label: scheduleText,
                                    color: primaryColor,
                                  ),
                                if (cell.leaderName != null && !isOwnCell)
                                  _HeaderChip(
                                    icon: Icons.person_rounded,
                                    label: cell.leaderName!,
                                    color: primaryColor,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                actions: const [],
              ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
              // ── Card Participantes ──
              _HubTile(
                icon: Icons.people_rounded,
                iconColor: primaryColor,
                iconBgColor: primaryColor.withValues(alpha: 0.1),
                title: 'Participantes',
                subtitle: '$memberCount membros · $visitorCount visitantes',
                onTap: () => Navigator.pushNamed(context, '/cell-members'),
              ),

              const SizedBox(height: 8),

              // ── Card Reuniões ──
              _HubTile(
                icon: Icons.event_note_rounded,
                iconColor: primaryColor,
                iconBgColor: primaryColor.withValues(alpha: 0.1),
                title: 'Reuniões',
                subtitle: _buildMeetingSubtitle(meetings.length, lastMeetingDays),
                onTap: () => Navigator.pushNamed(context, '/cell-meetings'),
              ),

              // ── Card Editar discreto ──
              if (canEdit) ...[
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () =>
                        Navigator.pushNamed(context, '/edit-cell'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined,
                              size: 18, color: Colors.grey[400]),
                          const SizedBox(width: 10),
                          Text(
                            'Editar célula',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.chevron_right,
                              size: 18, color: Colors.grey[300]),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _buildMeetingSubtitle(int total, int? lastDays) {
    if (total == 0) return 'Nenhuma reunião registrada';
    final lastText = lastDays != null
        ? (lastDays == 0
            ? 'Última reunião hoje'
            : lastDays == 1
                ? 'Última reunião ontem'
                : 'Última reunião há $lastDays dias')
        : '';
    return lastText;
  }

}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _HubTile({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _HeaderChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
