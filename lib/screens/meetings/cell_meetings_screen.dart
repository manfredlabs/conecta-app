import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cell_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/permissions.dart';
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

class CellMeetingsScreen extends StatefulWidget {
  const CellMeetingsScreen({super.key});

  @override
  State<CellMeetingsScreen> createState() => _CellMeetingsScreenState();
}

class _CellMeetingsScreenState extends State<CellMeetingsScreen> {
  static _MeetingFilter _savedFilter = _MeetingFilter.threeMonths;
  _MeetingFilter _filter = _savedFilter;

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

  @override
  Widget build(BuildContext context) {
    return Consumer<CellProvider>(
      builder: (context, cellProvider, _) {
        final cell = cellProvider.selectedCell;
        if (cell == null) {
          return const Scaffold(
            body: Center(child: Text('Nenhuma célula selecionada')),
          );
        }

        final user = context.read<AuthProvider>().appUser;
        final canEdit = user != null && Permissions.canEditCell(user, cell);
        final theme = Theme.of(context);
        final primaryColor = theme.colorScheme.primary;

        final cutoff = _filterDate();
        final meetings = List<Meeting>.from(cellProvider.meetings)
          ..retainWhere((m) => m.date.isAfter(cutoff) || m.date.isAtSameMomentAs(cutoff))
          ..sort((a, b) => b.date.compareTo(a.date));

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
                        selectedColor: primaryColor.withValues(alpha: 0.1),
                        checkmarkColor: primaryColor,
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                          color: selected ? primaryColor : Colors.grey[600],
                        ),
                        side: BorderSide(
                          color: selected ? primaryColor : Colors.grey[300]!,
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
                child: meetings.isEmpty && !canEdit
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
                        itemCount: meetings.length + (canEdit ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Registrar Reunião card at top
                          if (canEdit && index == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Card(
                                color: primaryColor.withValues(alpha: 0.08),
                                elevation: 0,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    await Navigator.pushNamed(
                                        context, '/create-meeting');
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 14),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: primaryColor
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Icon(Icons.edit_note_rounded,
                                              color: primaryColor, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Registrar Reunião',
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: primaryColor,
                                          ),
                                        ),
                                        const Spacer(),
                                        Icon(Icons.chevron_right,
                                            color: primaryColor
                                                .withValues(alpha: 0.5)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          final meetingIndex =
                              canEdit ? index - 1 : index;
                          final meeting = meetings[meetingIndex];
                          return _MeetingCard(
                            meeting: meeting,
                            presentCount: meeting.presentMemberIds.length,
                            isFirst: meetingIndex == 0,
                          );
                        },
                      ),
              ),
            ],
          ),
          floatingActionButton: null,
        );
      },
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final Meeting meeting;
  final int presentCount;
  final bool isFirst;
  const _MeetingCard({required this.meeting, required this.presentCount, this.isFirst = false});

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

    // First card: show relative date if ≤14 days ago
    String title = '$weekday, $dateStr';
    if (isFirst) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final meetingDay = DateTime(meeting.date.year, meeting.date.month, meeting.date.day);
      final days = today.difference(meetingDay).inDays;
      if (days == 0) {
        title = 'Hoje';
      } else if (days == 1) {
        title = 'Ontem';
      } else if (days <= 14) {
        title = 'Há $days dias';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(
          context,
          '/meeting-detail',
          arguments: meeting,
        ),
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
                      title,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
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
