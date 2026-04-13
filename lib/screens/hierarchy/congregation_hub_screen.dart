import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/hierarchy_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/congregation_model.dart';
import '../../utils/permissions.dart';
import '../../config/theme.dart';

class CongregationHubScreen extends StatefulWidget {
  const CongregationHubScreen({super.key});

  @override
  State<CongregationHubScreen> createState() => _CongregationHubScreenState();
}

class _CongregationHubScreenState extends State<CongregationHubScreen> {
  final _db = FirebaseFirestore.instance;
  bool _loading = true;
  int _supervisionCount = 0;
  int _cellCount = 0;
  int _memberCount = 0;
  int _visitorCount = 0;
  int _cellsMet = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    await _ensureCongregation();
    if (mounted) _loadStats();
  }

  Future<void> _ensureCongregation() async {
    final hierarchy = context.read<HierarchyProvider>();
    if (hierarchy.selectedCongregation != null) return;

    final user = context.read<AuthProvider>().appUser;
    if (user?.congregationId == null) return;

    final doc = await _db.collection('congregations').doc(user!.congregationId).get();
    if (!mounted || !doc.exists) return;
    hierarchy.selectCongregation(Congregation.fromFirestore(doc));
  }

  Future<void> _loadStats() async {
    final hierarchy = context.read<HierarchyProvider>();
    final congregation = hierarchy.selectedCongregation;
    if (congregation == null) return;
    final churchId = congregation.churchId;

    // Supervisões
    Query<Map<String, dynamic>> supQuery = _db
        .collection('supervisions')
        .where('congregationId', isEqualTo: congregation.id);
    if (churchId != null) {
      supQuery = supQuery.where('churchId', isEqualTo: churchId);
    }
    final supSnap = await supQuery.get();

    // Células
    Query<Map<String, dynamic>> cellsQuery = _db
        .collection('cells')
        .where('congregationId', isEqualTo: congregation.id);
    if (churchId != null) {
      cellsQuery = cellsQuery.where('churchId', isEqualTo: churchId);
    }
    final cellsSnap = await cellsQuery.get();

    // Membros
    Query<Map<String, dynamic>> membersQuery = _db
        .collection('cell_members')
        .where('congregationId', isEqualTo: congregation.id);
    if (churchId != null) {
      membersQuery = membersQuery.where('churchId', isEqualTo: churchId);
    }
    final membersSnap = await membersQuery.get();
    final activeDocs = membersSnap.docs
        .where((d) => (d.data())['isActive'] != false)
        .toList();
    final uniquePersonIds = activeDocs
        .map((d) => d.data()['personId'] as String?)
        .whereType<String>()
        .toSet();
    final uniqueVisitorIds = activeDocs
        .where((d) => d.data()['isVisitor'] == true)
        .map((d) => d.data()['personId'] as String?)
        .whereType<String>()
        .toSet();

    // Reuniões esta semana
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekCutoff =
        DateTime(weekStart.year, weekStart.month, weekStart.day);

    Query<Map<String, dynamic>> meetingsQuery = _db
        .collection('meetings')
        .where('congregationId', isEqualTo: congregation.id);
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
        _supervisionCount = supSnap.size;
        _cellCount = cellsSnap.size;
        _memberCount = uniquePersonIds.length - uniqueVisitorIds.length;
        _visitorCount = uniqueVisitorIds.length;
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
    final congregation = hierarchy.selectedCongregation;

    if (congregation == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = context.read<AuthProvider>().appUser;
    final canEdit = user != null &&
        Permissions.canEditCongregation(user, congregationId: congregation.id);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.04),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
                              child: Icon(Icons.church_rounded,
                                  color: primaryColor, size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                congregation.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
                              icon: Icons.account_balance_rounded,
                              label: '$_supervisionCount supervisões',
                              color: primaryColor,
                            ),
                            _HeaderChip(
                              icon: Icons.groups_rounded,
                              label: '$_cellCount células',
                              color: primaryColor,
                            ),
                            if (congregation.pastorName != null)
                              _HeaderChip(
                                icon: Icons.person_rounded,
                                label: congregation.pastorName!,
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
                // ── Supervisões ──
                _HubTile(
                  icon: Icons.account_balance_rounded,
                  iconColor: primaryColor,
                  iconBgColor: primaryColor.withValues(alpha: 0.1),
                  title: 'Supervisões',
                  subtitle: _loading
                      ? 'Carregando...'
                      : '$_supervisionCount supervisões',
                  onTap: () async {
                    await Navigator.pushNamed(context, '/supervision-list');
                    if (mounted) _loadStats();
                  },
                ),

                const SizedBox(height: 8),

                // ── Células ──
                _HubTile(
                  icon: Icons.groups_rounded,
                  iconColor: primaryColor,
                  iconBgColor: primaryColor.withValues(alpha: 0.1),
                  title: 'Células',
                  subtitle: _loading
                      ? 'Carregando...'
                      : '$_cellCount células',
                  onTap: () async {
                    await Navigator.pushNamed(context, '/congregation-cells');
                    if (mounted) _loadStats();
                  },
                ),

                const SizedBox(height: 8),

                // ── Participantes ──
                _HubTile(
                  icon: Icons.people_rounded,
                  iconColor: primaryColor,
                  iconBgColor: primaryColor.withValues(alpha: 0.1),
                  title: 'Participantes',
                  subtitle: _loading
                      ? 'Carregando...'
                      : '$_memberCount membros · $_visitorCount visitantes',
                  onTap: () async {
                    await Navigator.pushNamed(context, '/congregation-members');
                    if (mounted) _loadStats();
                  },
                ),

                const SizedBox(height: 8),

                // ── Reuniões ──
                _HubTile(
                  icon: Icons.event_note_rounded,
                  iconColor: primaryColor,
                  iconBgColor: primaryColor.withValues(alpha: 0.1),
                  title: 'Reuniões',
                  subtitle: _loading
                      ? 'Carregando...'
                      : '$_cellsMet/$_cellCount células reuniram esta semana',
                  onTap: () async {
                    await Navigator.pushNamed(context, '/congregation-meetings');
                    if (mounted) _loadStats();
                  },
                ),

                // ── Editar (discreto) ──
                if (canEdit) ...[
                  const SizedBox(height: 8),
                  Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        await Navigator.pushNamed(context, '/edit-congregation');
                        if (mounted) _loadStats();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined,
                                size: 18, color: AppColors.neutral400),
                            const SizedBox(width: 10),
                            Text(
                              'Editar congregação',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.neutral500,
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.chevron_right,
                                size: 18, color: AppColors.neutral300),
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
  }
}

class _HubTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _HubTile({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
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
                          ?.copyWith(color: AppColors.neutral500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.neutral400),
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
  const _HeaderChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.55;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
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
      ),
    );
  }
}
