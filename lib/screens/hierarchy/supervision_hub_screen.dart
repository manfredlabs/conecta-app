import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/cell_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/hierarchy_provider.dart';
import '../../utils/permissions.dart';

class SupervisionHubScreen extends StatefulWidget {
  const SupervisionHubScreen({super.key});

  @override
  State<SupervisionHubScreen> createState() => _SupervisionHubScreenState();
}

class _SupervisionHubScreenState extends State<SupervisionHubScreen> {
  final _db = FirebaseFirestore.instance;
  bool _loading = true;
  int _memberCount = 0;
  int _visitorCount = 0;
  int _cellsMet = 0;
  int _totalCells = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _loadStats() async {
    final hierarchy = context.read<HierarchyProvider>();
    final supervision = hierarchy.selectedSupervision;
    if (supervision == null) return;
    final churchId = supervision.churchId;

    Query<Map<String, dynamic>> membersQuery = _db
        .collection('cell_members')
        .where('supervisionId', isEqualTo: supervision.id);
    if (churchId != null) {
      membersQuery = membersQuery.where('churchId', isEqualTo: churchId);
    }
    final membersSnap = await membersQuery.get();
    final activeDocs = membersSnap.docs
        .where((d) => (d.data())['isActive'] != false)
        .toList();
    final visitors = activeDocs
        .where((d) => (d.data())['isVisitor'] == true)
        .length;

    Query<Map<String, dynamic>> cellsQuery = _db
        .collection('cells')
        .where('supervisionId', isEqualTo: supervision.id);
    if (churchId != null) {
      cellsQuery = cellsQuery.where('churchId', isEqualTo: churchId);
    }
    final cellsSnap = await cellsQuery.get();

    // Semáforo: quantas células reuniram esta semana
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekCutoff = DateTime(weekStart.year, weekStart.month, weekStart.day);

    Query<Map<String, dynamic>> meetingsQuery = _db
        .collection('meetings')
        .where('supervisionId', isEqualTo: supervision.id);
    if (churchId != null) {
      meetingsQuery = meetingsQuery.where('churchId', isEqualTo: churchId);
    }
    final meetingsSnap = await meetingsQuery.get();
    final cellsMetThisWeek = <String>{};
    for (final mDoc in meetingsSnap.docs) {
      final data = mDoc.data();
      final ts = data['date'];
      if (ts == null || ts is! Timestamp) continue;
      final date = ts.toDate();
      if (date.isAfter(weekCutoff) || date.isAtSameMomentAs(weekCutoff)) {
        final cellId = data['cellId'] as String? ?? '';
        if (cellId.isNotEmpty) cellsMetThisWeek.add(cellId);
      }
    }

    if (mounted) {
      setState(() {
        _memberCount = activeDocs.length - visitors;
        _visitorCount = visitors;
        _totalCells = cellsSnap.size;
        _cellsMet = cellsMetThisWeek.length;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final hierarchy = context.watch<HierarchyProvider>();
    final supervision = hierarchy.selectedSupervision;

    if (supervision == null) {
      return const Scaffold(
        body: Center(child: Text('Nenhuma supervisão selecionada')),
      );
    }

    return Consumer<CellProvider>(
      builder: (context, cellProvider, _) {
        final cells = cellProvider.cells;
        final user = context.read<AuthProvider>().appUser;
        final canEdit = user != null &&
            Permissions.canEditSupervision(user, supervision);

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
                                  child: Icon(Icons.account_balance_rounded,
                                      color: primaryColor, size: 26),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    supervision.name,
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
                                _HeaderChip(
                                  icon: Icons.groups_rounded,
                                  label: '${cells.length} células',
                                  color: primaryColor,
                                ),
                                if (supervision.supervisorName != null)
                                  _HeaderChip(
                                    icon: Icons.person_rounded,
                                    label: supervision.supervisorName!,
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
                    // ── Card Células ──
                    _HubTile(
                      icon: Icons.groups_rounded,
                      iconColor: primaryColor,
                      iconBgColor: primaryColor.withValues(alpha: 0.1),
                      title: 'Células',
                      subtitle: _loading
                          ? 'Carregando...'
                          : '$_totalCells células',
                      onTap: () async {
                        await Navigator.pushNamed(context, '/cell-list');
                        if (mounted) _loadStats();
                      },
                    ),

                    const SizedBox(height: 8),

                    // ── Card Participantes ──
                    _HubTile(
                      icon: Icons.people_rounded,
                      iconColor: primaryColor,
                      iconBgColor: primaryColor.withValues(alpha: 0.1),
                      title: 'Participantes',
                      subtitle: _loading
                          ? 'Carregando...'
                          : '$_memberCount membros · $_visitorCount visitantes',
                      onTap: () async {
                        await Navigator.pushNamed(context, '/supervision-members');
                        if (mounted) _loadStats();
                      },
                    ),

                    const SizedBox(height: 8),

                    // ── Card Reuniões ──
                    _HubTile(
                      icon: Icons.event_note_rounded,
                      iconColor: primaryColor,
                      iconBgColor: primaryColor.withValues(alpha: 0.1),
                      title: 'Reuniões',
                      subtitle: _loading
                          ? 'Carregando...'
                          : '$_cellsMet/$_totalCells células reuniram esta semana',
                      onTap: () async {
                        await Navigator.pushNamed(
                          context,
                          '/supervision-meetings',
                          arguments: supervision.id,
                        );
                        if (mounted) _loadStats();
                      },
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
                          onTap: () async {
                            await Navigator.pushNamed(context, '/edit-supervision');
                            if (mounted) _loadStats();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined,
                                    size: 18, color: Colors.grey[400]),
                                const SizedBox(width: 10),
                                Text(
                                  'Editar supervisão',
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
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
