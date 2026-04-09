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
import '../../utils/role_colors.dart';

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
      final ts = (d.data() as Map<String, dynamic>)['date'];
      if (ts == null || ts is! Timestamp) return false;
      final date = ts.toDate();
      return date.isAfter(monthStart) || date.isAtSameMomentAs(monthStart);
    }).length;
  }

  Future<void> _loadStats() async {
    final auth = context.read<AuthProvider>();
    final user = auth.appUser;
    if (user == null) return;
    final churchId = auth.churchId;

    final stats = <String, dynamic>{};

    // ── Minhas Células (busca por personId onde é líder) ──
    final myCells = <Map<String, dynamic>>[];
    if (user.personId != null) {
      Query<Map<String, dynamic>> leaderQuery = _db
          .collection('cell_members')
          .where('personId', isEqualTo: user.personId)
          .where('isLeader', isEqualTo: true)
          .where('isActive', isEqualTo: true);
      if (churchId != null) {
        leaderQuery = leaderQuery.where('churchId', isEqualTo: churchId);
      }
      final leaderSnap = await leaderQuery.get();

      for (final doc in leaderSnap.docs) {
        final cmData = doc.data();
        final cellId = cmData['cellId'] as String? ?? '';
        if (cellId.isEmpty) continue;

        final cellDoc = await _db.collection('cells').doc(cellId).get();
        if (!cellDoc.exists) continue;
        final cellData = cellDoc.data() as Map<String, dynamic>;

        final membersSnap = await _db
            .collection('cell_members')
            .where('cellId', isEqualTo: cellId)
            .get();
        final allMembers = membersSnap.docs.map((d) => d.data()).toList();
        final active = allMembers.where((m) => m['isActive'] != false).toList();
        final visitors = active.where((m) => m['isVisitor'] == true).length;

        final meetingsSnap = await _db
            .collection('meetings')
            .where('cellId', isEqualTo: cellId)
            .get();

        String lastMeeting = 'Nunca';
        int lastMeetingDays = -1;
        if (meetingsSnap.docs.isNotEmpty) {
          DateTime latest = DateTime(2000);
          for (final mDoc in meetingsSnap.docs) {
            final ts = mDoc.data()['date'];
            if (ts == null || ts is! Timestamp) continue;
            final date = ts.toDate();
            if (date.isAfter(latest)) latest = date;
          }
          lastMeetingDays = DateTime.now().difference(latest).inDays;
          lastMeeting = _formatDaysAgo(lastMeetingDays);
        }

        myCells.add({
          'cellId': cellId,
          'cellName': cellData['name'] ?? 'Célula',
          'cellMeetingDay': cellData['meetingDay'],
          'cellMeetingTime': cellData['meetingTime'],
          'cellAddress': cellData['address'],
          'cellMembers': active.length - visitors,
          'cellVisitors': visitors,
          'cellTotal': active.length,
          'cellLastMeeting': lastMeeting,
          'cellLastMeetingDays': lastMeetingDays,
        });
      }
    }

    // Fallback: se não achou por personId, busca cells onde leaderId == user.id
    if (myCells.isEmpty) {
      Query<Map<String, dynamic>> leaderCellsQuery = _db
          .collection('cells')
          .where('leaderId', isEqualTo: user.id);
      if (churchId != null) {
        leaderCellsQuery = leaderCellsQuery.where('churchId', isEqualTo: churchId);
      }
      final leaderCellsSnap = await leaderCellsQuery.get();

      for (final cellDoc in leaderCellsSnap.docs) {
        final cellData = cellDoc.data();
        final cellId = cellDoc.id;

        final membersSnap = await _db
            .collection('cell_members')
            .where('cellId', isEqualTo: cellId)
            .get();
        final allMembers = membersSnap.docs.map((d) => d.data()).toList();
        final active = allMembers.where((m) => m['isActive'] != false).toList();
        final visitors = active.where((m) => m['isVisitor'] == true).length;

        final meetingsSnap = await _db
            .collection('meetings')
            .where('cellId', isEqualTo: cellId)
            .get();

        String lastMeeting = 'Nunca';
        int lastMeetingDays = -1;
        if (meetingsSnap.docs.isNotEmpty) {
          DateTime latest = DateTime(2000);
          for (final mDoc in meetingsSnap.docs) {
            final ts = mDoc.data()['date'];
            if (ts == null || ts is! Timestamp) continue;
            final date = ts.toDate();
            if (date.isAfter(latest)) latest = date;
          }
          lastMeetingDays = DateTime.now().difference(latest).inDays;
          lastMeeting = _formatDaysAgo(lastMeetingDays);
        }

        myCells.add({
          'cellId': cellId,
          'cellName': cellData['name'] ?? 'Célula',
          'cellMeetingDay': cellData['meetingDay'],
          'cellMeetingTime': cellData['meetingTime'],
          'cellAddress': cellData['address'],
          'cellMembers': active.length - visitors,
          'cellVisitors': visitors,
          'cellTotal': active.length,
          'cellLastMeeting': lastMeeting,
          'cellLastMeetingDays': lastMeetingDays,
        });
      }
    }

    stats['myCells'] = myCells;

    // ── Minha Supervisão (supervisor ou pastor com supervisionId) ──
    if (user.supervisionId != null &&
        (user.role == UserRole.supervisor || user.role == UserRole.pastor || user.role == UserRole.admin)) {
      final supDoc = await _db.collection('supervisions').doc(user.supervisionId).get();
      if (supDoc.exists) {
        stats['supName'] = (supDoc.data() as Map<String, dynamic>)['name'] ?? 'Supervisão';
      }

      Query<Map<String, dynamic>> supCellsQuery = _db
          .collection('cells')
          .where('supervisionId', isEqualTo: user.supervisionId);
      if (churchId != null) {
        supCellsQuery = supCellsQuery.where('churchId', isEqualTo: churchId);
      }
      final cellsSnap = await supCellsQuery.get();
      stats['supCells'] = cellsSnap.size;

      Query<Map<String, dynamic>> supMembersQuery = _db
          .collection('cell_members')
          .where('supervisionId', isEqualTo: user.supervisionId);
      if (churchId != null) {
        supMembersQuery = supMembersQuery.where('churchId', isEqualTo: churchId);
      }
      final membersSnap = await supMembersQuery.get();
      final activeDocs = membersSnap.docs
          .where((d) => (d.data())['isActive'] != false)
          .toList();
      final supVisitors = activeDocs
          .where((d) => (d.data())['isVisitor'] == true)
          .length;
      stats['supMembers'] = activeDocs.length - supVisitors;
      stats['supVisitors'] = supVisitors;

      // Semáforo: quantas células reuniram esta semana
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      final weekCutoff = DateTime(weekStart.year, weekStart.month, weekStart.day);

      Query<Map<String, dynamic>> supMeetingsQuery = _db
          .collection('meetings')
          .where('supervisionId', isEqualTo: user.supervisionId);
      if (churchId != null) {
        supMeetingsQuery = supMeetingsQuery.where('churchId', isEqualTo: churchId);
      }
      final meetingsSnap = await supMeetingsQuery.get();
      stats['supWeeklyMeetings'] = _countRecentMeetings(meetingsSnap.docs);

      // Contar células distintas que reuniram esta semana
      final cellsMetThisWeek = <String>{};
      for (final mDoc in meetingsSnap.docs) {
        final data = mDoc.data() as Map<String, dynamic>;
        final ts = data['date'];
        if (ts == null || ts is! Timestamp) continue;
        final date = ts.toDate();
        if (date.isAfter(weekCutoff) || date.isAtSameMomentAs(weekCutoff)) {
          final cellId = data['cellId'] as String? ?? '';
          if (cellId.isNotEmpty) cellsMetThisWeek.add(cellId);
        }
      }
      stats['supCellsMet'] = cellsMetThisWeek.length;
    }

    // ── Congregação (pastor) ──
    if (user.role == UserRole.pastor && user.congregationId != null) {
      final congDoc = await _db.collection('congregations').doc(user.congregationId).get();
      if (congDoc.exists) {
        stats['congName'] = (congDoc.data() as Map<String, dynamic>)['name'] ?? 'Congregação';
      }

      Query<Map<String, dynamic>> congSupsQuery = _db
          .collection('supervisions')
          .where('congregationId', isEqualTo: user.congregationId);
      if (churchId != null) {
        congSupsQuery = congSupsQuery.where('churchId', isEqualTo: churchId);
      }
      final supervisionsSnap = await congSupsQuery.get();
      stats['congSupervisions'] = supervisionsSnap.size;

      Query<Map<String, dynamic>> congCellsQuery = _db
          .collection('cells')
          .where('congregationId', isEqualTo: user.congregationId);
      if (churchId != null) {
        congCellsQuery = congCellsQuery.where('churchId', isEqualTo: churchId);
      }
      final cellsSnap = await congCellsQuery.get();
      stats['congCells'] = cellsSnap.size;

      Query<Map<String, dynamic>> congMembersQuery = _db
          .collection('cell_members')
          .where('congregationId', isEqualTo: user.congregationId);
      if (churchId != null) {
        congMembersQuery = congMembersQuery.where('churchId', isEqualTo: churchId);
      }
      final membersSnap = await congMembersQuery.get();
      final activeCongMembers = membersSnap.docs
          .where((d) => (d.data())['isActive'] != false)
          .length;
      stats['congMembers'] = activeCongMembers;

      Query<Map<String, dynamic>> congMeetingsQuery = _db
          .collection('meetings')
          .where('congregationId', isEqualTo: user.congregationId);
      if (churchId != null) {
        congMeetingsQuery = congMeetingsQuery.where('churchId', isEqualTo: churchId);
      }
      final meetingsSnap = await congMeetingsQuery.get();
      stats['congWeeklyMeetings'] = _countRecentMeetings(meetingsSnap.docs);
    }

    // ── Admin (tudo) ──
    if (user.role == UserRole.admin) {
      Query<Map<String, dynamic>> congQuery = _db.collection('congregations');
      if (churchId != null) {
        congQuery = congQuery.where('churchId', isEqualTo: churchId);
      }
      final congSnap = await congQuery.get();
      stats['adminCongregations'] = congSnap.size;

      Query<Map<String, dynamic>> cellsQuery = _db.collection('cells');
      if (churchId != null) {
        cellsQuery = cellsQuery.where('churchId', isEqualTo: churchId);
      }
      final cellsSnap = await cellsQuery.get();
      stats['adminCells'] = cellsSnap.size;

      Query<Map<String, dynamic>> membersQuery = _db.collection('cell_members');
      if (churchId != null) {
        membersQuery = membersQuery.where('churchId', isEqualTo: churchId);
      }
      final membersSnap = await membersQuery.get();
      stats['adminMembers'] = membersSnap.size;

      Query<Map<String, dynamic>> pendingQuery = _db
          .collection('approval_requests')
          .where('status', isEqualTo: 'pending');
      if (churchId != null) {
        pendingQuery = pendingQuery.where('churchId', isEqualTo: churchId);
      }
      final pendingSnap = await pendingQuery.get();
      stats['pendingApprovals'] = pendingSnap.size;
    }

    if (mounted) {
      setState(() {
        _stats = stats;
        _loading = false;
      });
    }
  }

  Future<void> _navigateToCellHub([String? cellId]) async {
    final user = context.read<AuthProvider>().appUser;
    final cellProvider = context.read<CellProvider>();
    final targetCellId = cellId ?? user?.cellId;
    if (user == null || targetCellId == null) return;

    final cellDoc = await _db.collection('cells').doc(targetCellId).get();
    if (!mounted || !cellDoc.exists) return;
    final cell = CellGroup.fromFirestore(cellDoc);
    cellProvider.selectCell(cell);
    await Navigator.pushNamed(context, '/cell-hub');
    if (mounted) _loadStats();
  }

  Future<void> _navigateToCreateMeeting([String? cellId]) async {
    final user = context.read<AuthProvider>().appUser;
    final cellProvider = context.read<CellProvider>();
    final targetCellId = cellId ?? user?.cellId;
    if (user == null || targetCellId == null) return;

    final cellDoc = await _db.collection('cells').doc(targetCellId).get();
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
    cellProvider.listenToCells(supervisionId: supervision.id, churchId: supervision.churchId);
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
    final myCells = (_stats['myCells'] as List<Map<String, dynamic>>?) ?? [];
    if (myCells.isEmpty) return [];

    final widgets = <Widget>[];
    widgets.add(_sectionTitle(myCells.length == 1 ? 'Sua célula' : 'Suas células'));

    for (int i = 0; i < myCells.length; i++) {
      if (i > 0) widgets.add(const SizedBox(height: 8));
      widgets.addAll(_buildSingleCellCard(myCells[i]));
    }

    return widgets;
  }

  List<Widget> _buildSingleCellCard(Map<String, dynamic> cellStats) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final cellId = cellStats['cellId'] as String;
    final cellName = cellStats['cellName'] ?? 'Célula';
    final meetingDay = cellStats['cellMeetingDay'] as String?;
    final meetingTime = cellStats['cellMeetingTime'] as String?;
    final members = cellStats['cellMembers'] ?? 0;
    final visitors = cellStats['cellVisitors'] ?? 0;
    final lastMeeting = cellStats['cellLastMeeting'] ?? 'Nunca';
    final lastMeetingDays = cellStats['cellLastMeetingDays'] ?? -1;

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
      Card(
        clipBehavior: Clip.antiAlias,
        color: primaryColor.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              onTap: () => _navigateToCellHub(cellId),
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
                          color: Colors.grey[600]!,
                        ),
                        _StatChip(
                          icon: Icons.person_add_rounded,
                          label: '$visitors visitantes',
                          color: Colors.grey[600]!,
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
            // Divider
            Divider(height: 1, thickness: 1, color: Colors.grey[200]),
            // Registrar Reunião button inside card
            Material(
              color: primaryColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              child: InkWell(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                onTap: () => _navigateToCreateMeeting(cellId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.edit_note_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Registrar Reunião',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right, color: Colors.white70, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
    final supVisitors = _stats['supVisitors'] ?? 0;
    final supCellsMet = _stats['supCellsMet'] ?? 0;

    // Semáforo: cor baseada em % de células que reuniram
    Color semaphoreColor;
    if (supCells == 0) {
      semaphoreColor = Colors.grey;
    } else {
      final pct = supCellsMet / supCells;
      if (pct >= 0.75) {
        semaphoreColor = Colors.green;
      } else if (pct >= 0.50) {
        semaphoreColor = Colors.orange;
      } else {
        semaphoreColor = Colors.red;
      }
    }

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
                      label: '$supMembers membros',
                      color: Colors.grey[600]!,
                    ),
                    _StatChip(
                      icon: Icons.person_add_rounded,
                      label: '$supVisitors visitantes',
                      color: Colors.grey[600]!,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _StatChip(
                  icon: Icons.groups_rounded,
                  label: '$supCellsMet/$supCells células reuniram esta semana',
                  color: semaphoreColor,
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

    // Minha(s) Célula(s)
    final myCells = (_stats['myCells'] as List<Map<String, dynamic>>?) ?? [];
    if (myCells.isNotEmpty) {
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
      final pendingCount = _stats['pendingApprovals'] ?? 0;
      sections.addAll([
        if (pendingCount > 0) ...[
          _StatTile(
            icon: Icons.pending_actions_rounded,
            color: Colors.orange[700]!,
            title: '$pendingCount Solicitaç${pendingCount == 1 ? 'ão' : 'ões'}',
            subtitle: 'Aguardando aprovação',
            onTap: () => Navigator.pushNamed(context, '/approval-requests'),
          ),
          const SizedBox(height: 8),
        ],
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

    // Líder sem célula
    if (user.role == UserRole.leader && myCells.isEmpty) {
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
