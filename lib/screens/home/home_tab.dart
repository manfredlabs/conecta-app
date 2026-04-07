import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cell_provider.dart';
import '../../providers/hierarchy_provider.dart';
import '../../models/user_model.dart';
import '../../models/cell_model.dart';
import '../../models/supervision_model.dart';
import '../../models/congregation_model.dart';

class HomeTab extends StatefulWidget {
  final void Function(int)? onSwitchTab;
  const HomeTab({super.key, this.onSwitchTab});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _db = FirebaseFirestore.instance;
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  String _formatDaysAgo(int daysAgo) {
    if (daysAgo == 0) return 'Hoje';
    if (daysAgo == 1) return 'Ontem';
    return 'Há $daysAgo dias';
  }

  int _countRecentMeetings(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    return docs.where((d) {
      final date = (d.data() as Map<String, dynamic>)['date'] as Timestamp;
      return date.toDate().isAfter(monthStart) || date.toDate().isAtSameMomentAs(monthStart);
    }).length;
  }

  Future<void> _loadStats() async {
    final user = context.read<AuthProvider>().appUser;
    if (user == null) return;

    final stats = <String, dynamic>{};

    // ── Minha Célula (qualquer usuário com cellId) ──
    if (user.cellId != null) {
      final cellDoc = await _db.collection('cells').doc(user.cellId).get();
      if (cellDoc.exists) {
        final cellData = cellDoc.data() as Map<String, dynamic>;
        stats['cellName'] = cellData['name'] ?? 'Célula';
        stats['cellMeetingDay'] = cellData['meetingDay'];
        stats['cellMeetingTime'] = cellData['meetingTime'];
        stats['cellAddress'] = cellData['address'];
      }

      final membersSnap = await _db
          .collection('cell_members')
          .where('cellId', isEqualTo: user.cellId)
          .get();
      final allMembers = membersSnap.docs.map((d) => d.data()).toList();
      final active = allMembers.where((m) => m['isActive'] != false).toList();
      final visitors = active.where((m) => m['isVisitor'] == true).length;
      stats['cellTotal'] = active.length;
      stats['cellMembers'] = active.length - visitors;
      stats['cellVisitors'] = visitors;

      final meetingsSnap = await _db
          .collection('meetings')
          .where('cellId', isEqualTo: user.cellId)
          .get();
      if (meetingsSnap.docs.isNotEmpty) {
        DateTime latest = DateTime(2000);
        for (final doc in meetingsSnap.docs) {
          final date = (doc.data()['date'] as Timestamp).toDate();
          if (date.isAfter(latest)) latest = date;
        }
        final daysAgo = DateTime.now().difference(latest).inDays;
        stats['cellLastMeeting'] = _formatDaysAgo(daysAgo);
        stats['cellLastMeetingDays'] = daysAgo;
      } else {
        stats['cellLastMeeting'] = 'Nunca';
        stats['cellLastMeetingDays'] = -1;
      }
    }

    // ── Minha Supervisão (supervisor ou pastor com supervisionId) ──
    if (user.supervisionId != null &&
        (user.role == UserRole.supervisor || user.role == UserRole.pastor || user.role == UserRole.admin)) {
      final supDoc = await _db.collection('supervisions').doc(user.supervisionId).get();
      if (supDoc.exists) {
        stats['supName'] = (supDoc.data() as Map<String, dynamic>)['name'] ?? 'Supervisão';
      }

      final cellsSnap = await _db
          .collection('cells')
          .where('supervisionId', isEqualTo: user.supervisionId)
          .get();
      stats['supCells'] = cellsSnap.size;

      final membersSnap = await _db
          .collection('cell_members')
          .where('supervisionId', isEqualTo: user.supervisionId)
          .get();
      final activeSupMembers = membersSnap.docs
          .where((d) => (d.data())['isActive'] != false)
          .length;
      stats['supMembers'] = activeSupMembers;

      final meetingsSnap = await _db
          .collection('meetings')
          .where('supervisionId', isEqualTo: user.supervisionId)
          .get();
      stats['supWeeklyMeetings'] = _countRecentMeetings(meetingsSnap.docs);
    }

    // ── Congregação (pastor) ──
    if (user.role == UserRole.pastor && user.congregationId != null) {
      final congDoc = await _db.collection('congregations').doc(user.congregationId).get();
      if (congDoc.exists) {
        stats['congName'] = (congDoc.data() as Map<String, dynamic>)['name'] ?? 'Congregação';
      }

      final supervisionsSnap = await _db
          .collection('supervisions')
          .where('congregationId', isEqualTo: user.congregationId)
          .get();
      stats['congSupervisions'] = supervisionsSnap.size;

      final cellsSnap = await _db
          .collection('cells')
          .where('congregationId', isEqualTo: user.congregationId)
          .get();
      stats['congCells'] = cellsSnap.size;

      final membersSnap = await _db
          .collection('cell_members')
          .where('congregationId', isEqualTo: user.congregationId)
          .get();
      final activeCongMembers = membersSnap.docs
          .where((d) => (d.data())['isActive'] != false)
          .length;
      stats['congMembers'] = activeCongMembers;

      final meetingsSnap = await _db
          .collection('meetings')
          .where('congregationId', isEqualTo: user.congregationId)
          .get();
      stats['congWeeklyMeetings'] = _countRecentMeetings(meetingsSnap.docs);
    }

    // ── Admin (tudo) ──
    if (user.role == UserRole.admin) {
      final congSnap = await _db.collection('congregations').get();
      stats['adminCongregations'] = congSnap.size;

      final cellsSnap = await _db.collection('cells').get();
      stats['adminCells'] = cellsSnap.size;

      final membersSnap = await _db.collection('cell_members').get();
      stats['adminMembers'] = membersSnap.size;
    }

    if (mounted) {
      setState(() {
        _stats = stats;
        _loading = false;
      });
    }
  }

  Future<void> _navigateToCellHub() async {
    final user = context.read<AuthProvider>().appUser;
    final cellProvider = context.read<CellProvider>();
    if (user == null || user.cellId == null) return;

    final cellDoc = await _db.collection('cells').doc(user.cellId).get();
    if (!mounted || !cellDoc.exists) return;
    final cell = CellGroup.fromFirestore(cellDoc);
    cellProvider.selectCell(cell);
    await Navigator.pushNamed(context, '/cell-hub');
    if (mounted) _loadStats();
  }

  Future<void> _navigateToCreateMeeting() async {
    final user = context.read<AuthProvider>().appUser;
    final cellProvider = context.read<CellProvider>();
    if (user == null || user.cellId == null) return;

    final cellDoc = await _db.collection('cells').doc(user.cellId).get();
    if (!mounted || !cellDoc.exists) return;
    final cell = CellGroup.fromFirestore(cellDoc);
    cellProvider.selectCell(cell);
    await Navigator.pushNamed(context, '/create-meeting');
    if (mounted) _loadStats();
  }

  Future<void> _navigateToMySupervisionHub() async {
    final user = context.read<AuthProvider>().appUser;
    final hierarchyProvider = context.read<HierarchyProvider>();
    final cellProvider = context.read<CellProvider>();
    if (user == null || user.supervisionId == null) return;

    final supDoc = await _db.collection('supervisions').doc(user.supervisionId).get();
    if (!mounted || !supDoc.exists) return;
    final supervision = Supervision.fromFirestore(supDoc);
    hierarchyProvider.selectSupervision(supervision);
    cellProvider.listenToCells(supervisionId: supervision.id);
    await Navigator.pushNamed(context, '/supervision-hub');
    if (mounted) _loadStats();
  }

  Future<void> _navigateToCongregationHub() async {
    final user = context.read<AuthProvider>().appUser;
    final hierarchyProvider = context.read<HierarchyProvider>();
    if (user == null || user.congregationId == null) return;

    if (hierarchyProvider.selectedCongregation == null) {
      final doc = await _db.collection('congregations').doc(user.congregationId).get();
      if (!mounted || !doc.exists) return;
      final congregation = Congregation.fromFirestore(doc);
      hierarchyProvider.selectCongregation(congregation);
    }
    if (mounted) {
      await Navigator.pushNamed(context, '/congregation-hub');
      if (mounted) _loadStats();
    }
  }

  Future<void> _navigateToCongregationMembers() async {
    final user = context.read<AuthProvider>().appUser;
    final hierarchyProvider = context.read<HierarchyProvider>();
    if (user == null || user.congregationId == null) return;

    if (hierarchyProvider.selectedCongregation == null) {
      final doc = await _db.collection('congregations').doc(user.congregationId).get();
      if (!mounted || !doc.exists) return;
      final congregation = Congregation.fromFirestore(doc);
      hierarchyProvider.selectCongregation(congregation);
    }
    if (mounted) {
      await Navigator.pushNamed(context, '/congregation-members');
      if (mounted) _loadStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.appUser;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Text(
                'Olá, ${user.name.split(' ').first}!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),

          // Quick stats section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _loading
                  ? const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _buildQuickStats(context, user),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  // ── Seções reutilizáveis ──

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
      ),
    );
  }

  List<Widget> _buildMinhaCelulaSection() {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final cellName = _stats['cellName'] ?? 'Célula';
    final meetingDay = _stats['cellMeetingDay'] as String?;
    final meetingTime = _stats['cellMeetingTime'] as String?;
    final members = _stats['cellMembers'] ?? 0;
    final visitors = _stats['cellVisitors'] ?? 0;
    final lastMeeting = _stats['cellLastMeeting'] ?? 'Nunca';
    final lastMeetingDays = _stats['cellLastMeetingDays'] ?? -1;

    Color meetingIconColor;
    if (lastMeetingDays < 0) {
      meetingIconColor = Colors.grey;
    } else if (lastMeetingDays <= 7) {
      meetingIconColor = Colors.green;
    } else if (lastMeetingDays <= 14) {
      meetingIconColor = Colors.orange;
    } else {
      meetingIconColor = Colors.red;
    }

    final schedule = [
      ?meetingDay,
      ?meetingTime,
    ].join(' · ');

    return [
      _sectionTitle('Sua célula'),
      Card(
        clipBehavior: Clip.antiAlias,
        color: primaryColor.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _navigateToCellHub(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.groups_rounded,
                          color: primaryColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cellName,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (schedule.isNotEmpty)
                            Text(
                              schedule,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[500]),
                            ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatChip(
                      icon: Icons.people_rounded,
                      label: '$members membros',
                      color: primaryColor,
                    ),
                    _StatChip(
                      icon: Icons.person_add_rounded,
                      label: '$visitors visitantes',
                      color: primaryColor.withValues(alpha: 0.6),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatChip(
                      icon: Icons.schedule_rounded,
                      label: 'Última reunião: $lastMeeting',
                      color: meetingIconColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        color: primaryColor,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _navigateToCreateMeeting(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit_note_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Registrar Reunião',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Icon(Icons.chevron_right, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildMinhaSupervicaoSection() {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final supName = _stats['supName'] ?? 'Supervisão';
    final supCells = _stats['supCells'] ?? 0;
    final supMembers = _stats['supMembers'] ?? 0;
    final supMeetings = _stats['supWeeklyMeetings'] ?? 0;

    return [
      _sectionTitle('Sua supervisão'),
      Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _navigateToMySupervisionHub(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.account_balance_rounded,
                          color: primaryColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supName,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '$supCells células',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatChip(
                      icon: Icons.people_rounded,
                      label: '$supMembers participantes',
                      color: primaryColor,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.event_note_rounded,
                        size: 15, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      'Este mês: $supMeetings reuniões',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildCongregacaoSection() {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final congName = _stats['congName'] ?? 'Congregação';
    final congSupervisions = _stats['congSupervisions'] ?? 0;
    final congCells = _stats['congCells'] ?? 0;
    final congMembers = _stats['congMembers'] ?? 0;
    final congMeetings = _stats['congWeeklyMeetings'] ?? 0;

    return [
      _sectionTitle('Sua congregação'),
      Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _navigateToCongregationHub(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.church_rounded,
                          color: primaryColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            congName,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '$congSupervisions supervisões · $congCells células',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    GestureDetector(
                      onTap: () => _navigateToCongregationMembers(),
                      child: _StatChip(
                        icon: Icons.people_rounded,
                        label: '$congMembers participantes',
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.event_note_rounded,
                        size: 15, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text(
                      'Este mês: $congMeetings reuniões',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildQuickStats(BuildContext context, AppUser user) {
    final sections = <Widget>[];

    // Minha Célula (qualquer role com cellId)
    if (user.cellId != null) {
      sections.addAll(_buildMinhaCelulaSection());
    }

    // Minha Supervisão (supervisor ou pastor com supervisionId)
    if (user.supervisionId != null &&
        (user.role == UserRole.supervisor || user.role == UserRole.pastor || user.role == UserRole.admin)) {
      if (sections.isNotEmpty) sections.add(const SizedBox(height: 28));
      sections.addAll(_buildMinhaSupervicaoSection());
    }

    // Congregação (pastor)
    if (user.role == UserRole.pastor) {
      if (sections.isNotEmpty) sections.add(const SizedBox(height: 28));
      sections.addAll(_buildCongregacaoSection());
    }

    // Admin
    if (user.role == UserRole.admin) {
      final color = Theme.of(context).colorScheme.primary;
      sections.addAll([
        _StatTile(
          icon: Icons.account_balance_rounded,
          color: color,
          title: '${_stats['adminCongregations'] ?? 0} Congregações',
          subtitle: '${_stats['adminCells'] ?? 0} células no total',
          onTap: () => widget.onSwitchTab?.call(1),
        ),
        const SizedBox(height: 8),
        _StatTile(
          icon: Icons.people_rounded,
          color: color,
          title: '${_stats['adminMembers'] ?? 0} Membros',
          subtitle: 'Em toda a rede',
          onTap: () => widget.onSwitchTab?.call(1),
        ),
      ]);
    }

    // Líder sem célula = título "Minha Célula" apenas
    if (user.role == UserRole.leader && user.cellId == null) {
      sections.addAll([
        _sectionTitle('Sua célula'),
        _StatTile(
          icon: Icons.people_rounded,
          color: Theme.of(context).colorScheme.primary,
          title: 'Sem célula vinculada',
          subtitle: 'Entre em contato com seu supervisor',
        ),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _StatTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
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
