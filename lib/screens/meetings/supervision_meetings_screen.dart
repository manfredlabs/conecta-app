import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/cell_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/meeting_model.dart';
import '../../config/theme.dart';

enum _MeetingFilter {
  all('Tudo'),
  week('Esta semana'),
  month('Este mês'),
  threeMonths('3 meses'),
  sixMonths('6 meses'),
  year('1 ano');

  final String label;
  const _MeetingFilter(this.label);
}

class SupervisionMeetingsScreen extends StatefulWidget {
  const SupervisionMeetingsScreen({super.key});

  @override
  State<SupervisionMeetingsScreen> createState() =>
      _SupervisionMeetingsScreenState();
}

class _SupervisionMeetingsScreenState extends State<SupervisionMeetingsScreen> {
  static _MeetingFilter _savedFilter = _MeetingFilter.threeMonths;
  _MeetingFilter _filter = _savedFilter;
  String _cellFilter = 'Todas';

  List<Meeting> _meetings = [];
  StreamSubscription? _meetingsSub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenMeetings());
  }

  @override
  void dispose() {
    _meetingsSub?.cancel();
    super.dispose();
  }

  void _listenMeetings() {
    final args = ModalRoute.of(context)?.settings.arguments;
    final auth = context.read<AuthProvider>();
    final user = auth.appUser;
    final churchId = auth.churchId;
    final supervisionId = args is String ? args : user?.supervisionId;
    if (supervisionId == null) return;

    // Ensure cells are loaded for name mapping
    context.read<CellProvider>().listenToCells(
          supervisionId: supervisionId,
          churchId: churchId,
        );

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('meetings')
        .where('supervisionId', isEqualTo: supervisionId);
    if (churchId != null) {
      query = query.where('churchId', isEqualTo: churchId);
    }
    _meetingsSub = query
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _meetings = snap.docs.map((d) => Meeting.fromFirestore(d)).toList()
            ..sort((a, b) => b.date.compareTo(a.date));
          _loading = false;
        });
      }
    });
  }

  DateTime _filterDate() {
    final now = DateTime.now();
    switch (_filter) {
      case _MeetingFilter.week:
        return now.subtract(Duration(days: now.weekday - 1));
      case _MeetingFilter.month:
        return DateTime(now.year, now.month, 1);
      case _MeetingFilter.threeMonths:
        return DateTime(now.year, now.month - 2, 1);
      case _MeetingFilter.sixMonths:
        return DateTime(now.year, now.month - 5, 1);
      case _MeetingFilter.year:
        return DateTime(now.year - 1, now.month, now.day);
      case _MeetingFilter.all:
        return DateTime(2000);
    }
  }

  void _onMeetingTap(Meeting meeting) {
    final cellProvider = context.read<CellProvider>();
    final cell = cellProvider.cells
        .where((c) => c.id == meeting.cellId)
        .firstOrNull;
    if (cell == null) return;
    cellProvider.selectCell(cell);
    Navigator.pushNamed(context, '/meeting-detail', arguments: meeting);
  }

  @override
  Widget build(BuildContext context) {
    final cells = context.watch<CellProvider>().cells;
    final cellMap = {for (final c in cells) c.id: c};

    final cutoff = _filterDate();
    var filtered = _meetings
        .where(
            (m) => m.date.isAfter(cutoff) || m.date.isAtSameMomentAs(cutoff))
        .toList();

    // Apply cell filter
    if (_cellFilter != 'Todas') {
      final cellId = cellMap.entries
          .where((e) => e.value.name == _cellFilter)
          .map((e) => e.key)
          .firstOrNull;
      if (cellId != null) {
        filtered = filtered.where((m) => m.cellId == cellId).toList();
      }
    }

    // Build sorted cell names for filter
    final cellNames = cells.map((c) => c.name).toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Reuniões')),
      body: Column(
        children: [
          // Period filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: _MeetingFilter.values.map((f) {
                final selected = f == _filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f.label),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _filter = f;
                      _savedFilter = f;
                    }),
                    selectedColor: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    checkmarkColor: Theme.of(context).colorScheme.primary,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : AppColors.neutral600,
                    ),
                    side: BorderSide(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : AppColors.neutral300,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Cell filter chips
          if (cellNames.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Row(
                children: ['Todas', ...cellNames].map((name) {
                  final selected = name == _cellFilter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(name),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _cellFilter = name;
                      }),
                      selectedColor: Theme.of(context)
                          .colorScheme
                          .tertiary
                          .withValues(alpha: 0.1),
                      checkmarkColor: Theme.of(context).colorScheme.tertiary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected
                            ? Theme.of(context).colorScheme.tertiary
                            : AppColors.neutral600,
                      ),
                      side: BorderSide(
                        color: selected
                            ? Theme.of(context).colorScheme.tertiary
                            : AppColors.neutral300,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.event_note_outlined,
                                size: 64, color: AppColors.neutral300),
                            const SizedBox(height: 16),
                            Text(
                              'Nenhuma reunião neste período',
                              style: TextStyle(
                                  color: AppColors.neutral400, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final meeting = filtered[index];
                          final cell = cellMap[meeting.cellId];
                          return _MeetingCard(
                            meeting: meeting,
                            cellName: cell?.name ?? '',
                            presentCount: meeting.presentMemberIds.length,
                            onTap: () => _onMeetingTap(meeting),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final Meeting meeting;
  final String cellName;
  final int presentCount;
  final VoidCallback onTap;

  const _MeetingCard({
    required this.meeting,
    required this.cellName,
    required this.presentCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr =
        '${meeting.date.day.toString().padLeft(2, '0')}/${meeting.date.month.toString().padLeft(2, '0')}/${meeting.date.year}';

    final weekdays = [
      'Segunda',
      'Terça',
      'Quarta',
      'Quinta',
      'Sexta',
      'Sábado',
      'Domingo',
    ];
    final weekday = weekdays[meeting.date.weekday - 1];

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
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.groups_outlined,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$weekday, $dateStr',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (cellName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        cellName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.neutral500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.neutral600.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$presentCount presentes',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.neutral600,
                            ),
                          ),
                        ),
                        if (meeting.observations != null &&
                            meeting.observations!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.notes_rounded,
                              size: 14, color: AppColors.neutral400),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.neutral400),
            ],
          ),
        ),
      ),
    );
  }
}
