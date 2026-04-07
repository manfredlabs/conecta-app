import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/cell_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/meeting_model.dart';

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

class CongregationMeetingsScreen extends StatefulWidget {
  const CongregationMeetingsScreen({super.key});

  @override
  State<CongregationMeetingsScreen> createState() =>
      _CongregationMeetingsScreenState();
}

class _CongregationMeetingsScreenState
    extends State<CongregationMeetingsScreen> {
  static _MeetingFilter _savedFilter = _MeetingFilter.threeMonths;
  _MeetingFilter _filter = _savedFilter;

  List<Meeting> _meetings = [];
  Map<String, String> _cellNames = {};
  Map<String, String> _cellToSupervision = {};
  Map<String, String> _supervisionNames = {};
  StreamSubscription? _meetingsSub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _meetingsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = context.read<AuthProvider>().appUser;
    if (user == null || user.congregationId == null) return;

    // Ensure cells are loaded
    context.read<CellProvider>().listenToCells(
          congregationId: user.congregationId,
        );

    // Load supervision names
    final supsSnap = await FirebaseFirestore.instance
        .collection('supervisions')
        .where('congregationId', isEqualTo: user.congregationId)
        .get();
    final supNames = <String, String>{};
    for (final doc in supsSnap.docs) {
      supNames[doc.id] = doc.data()['name'] ?? '';
    }
    if (mounted) setState(() => _supervisionNames = supNames);

    // Load cell names + map cell→supervision
    final cellsSnap = await FirebaseFirestore.instance
        .collection('cells')
        .where('congregationId', isEqualTo: user.congregationId)
        .get();
    final names = <String, String>{};
    final cellToSup = <String, String>{};
    for (final doc in cellsSnap.docs) {
      names[doc.id] = doc.data()['name'] ?? '';
      cellToSup[doc.id] = doc.data()['supervisionId'] ?? '';
    }
    if (mounted) {
      setState(() {
        _cellNames = names;
        _cellToSupervision = cellToSup;
      });
    }

    // Listen to meetings
    _meetingsSub = FirebaseFirestore.instance
        .collection('meetings')
        .where('congregationId', isEqualTo: user.congregationId)
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
    final cutoff = _filterDate();
    final filtered = _meetings
        .where(
            (m) => m.date.isAfter(cutoff) || m.date.isAtSameMomentAs(cutoff))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Reuniões')),
      body: Column(
        children: [
          // Filter chips
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
                          : Colors.grey[600],
                    ),
                    side: BorderSide(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey[300]!,
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
                                size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'Nenhuma reunião neste período',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final meeting = filtered[index];
                          final cellName =
                              _cellNames[meeting.cellId] ?? '';
                          final supId =
                              _cellToSupervision[meeting.cellId] ?? '';
                          final supName =
                              _supervisionNames[supId] ?? '';
                          return _MeetingCard(
                            meeting: meeting,
                            cellName: cellName,
                            supervisionName: supName,
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
  final String supervisionName;
  final int presentCount;
  final VoidCallback onTap;

  const _MeetingCard({
    required this.meeting,
    required this.cellName,
    required this.supervisionName,
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
      margin: const EdgeInsets.only(bottom: 8),
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
                    if (supervisionName.isNotEmpty || cellName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (supervisionName.isNotEmpty) supervisionName,
                          if (cellName.isNotEmpty) cellName,
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[500],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$presentCount presentes',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        if (meeting.observations != null &&
                            meeting.observations!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.notes_rounded,
                              size: 14, color: Colors.grey[400]),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
