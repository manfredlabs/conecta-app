import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/event_model.dart';
import '../../models/person_model.dart';
import '../../models/user_model.dart';

/// Representa um aniversário mapeado para o mês exibido
class _Birthday {
  final String name;
  final DateTime date; // dia/mês original (ano ignorado)
  _Birthday({required this.name, required this.date});
}

class AgendaTab extends StatefulWidget {
  const AgendaTab({super.key});

  @override
  State<AgendaTab> createState() => _AgendaTabState();
}

class _AgendaTabState extends State<AgendaTab> {
  final _service = FirestoreService();
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _showBirthdays = false;
  List<Person> _birthdayPeople = [];
  bool _loadingBirthdays = false;

  static const _prefKey = 'agenda_show_birthdays';

  @override
  void initState() {
    super.initState();
    _loadPref();
  }

  Future<void> _loadPref() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_prefKey) ?? false;
    if (saved != _showBirthdays) {
      setState(() => _showBirthdays = saved);
      if (_showBirthdays && _birthdayPeople.isEmpty) _loadBirthdays();
    }
  }

  // Cache de eventos para evitar rebuild do calendário inteiro
  List<ChurchEvent> _cachedEvents = [];
  Map<DateTime, List<ChurchEvent>> _cachedGrouped = {};
  Stream<List<ChurchEvent>>? _eventsStream;

  DateTime _normalizeDay(DateTime d) => DateTime(d.year, d.month, d.day);

  Map<DateTime, List<ChurchEvent>> _groupByDay(List<ChurchEvent> events) {
    final map = <DateTime, List<ChurchEvent>>{};
    for (final e in events) {
      final key = _normalizeDay(e.dateTime);
      map.putIfAbsent(key, () => []).add(e);
    }
    return map;
  }

  Map<DateTime, List<_Birthday>> _groupBirthdays() {
    final map = <DateTime, List<_Birthday>>{};
    if (!_showBirthdays) return map;
    for (final p in _birthdayPeople) {
      if (p.birthDate == null) continue;
      final key = DateTime(_focusedDay.year, p.birthDate!.month, p.birthDate!.day);
      map.putIfAbsent(_normalizeDay(key), () => []).add(
        _Birthday(name: p.name, date: p.birthDate!),
      );
    }
    return map;
  }

  List<ChurchEvent> _eventsForDay(
      DateTime day, Map<DateTime, List<ChurchEvent>> grouped) {
    return grouped[_normalizeDay(day)] ?? [];
  }

  List<_Birthday> _birthdaysForDay(
      DateTime day, Map<DateTime, List<_Birthday>> grouped) {
    return grouped[_normalizeDay(day)] ?? [];
  }

  Future<void> _loadBirthdays() async {
    if (_loadingBirthdays) return;
    setState(() => _loadingBirthdays = true);
    final auth = context.read<AuthProvider>();
    final people = await _service.getAllPeopleForBirthdays(churchId: auth.churchId);
    if (mounted) {
      setState(() {
        _birthdayPeople = people;
        _loadingBirthdays = false;
      });
    }
  }

  void _toggleBirthdays() async {
    setState(() => _showBirthdays = !_showBirthdays);
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool(_prefKey, _showBirthdays);
    if (_showBirthdays && _birthdayPeople.isEmpty) {
      _loadBirthdays();
    }
  }

  void _onDaySelected(DateTime selected, DateTime focused) {
    if (isSameDay(_selectedDay, selected)) return;
    setState(() {
      _selectedDay = selected;
      _focusedDay = focused;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.appUser;
    if (user == null) return const Center(child: CircularProgressIndicator());

    final isAdmin = user.role == UserRole.admin;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return SafeArea(
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Agenda',
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleBirthdays,
                    icon: Icon(
                      Icons.cake_outlined,
                      color: _showBirthdays ? const Color(0xFFFF7675) : Colors.grey[400],
                    ),
                    tooltip: 'Aniversários',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<ChurchEvent>>(
                stream: _eventsStream ??= _service.getEvents(churchId: auth.churchId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting &&
                      _cachedEvents.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snap.hasData) {
                    _cachedEvents = snap.data!;
                    _cachedGrouped = _groupByDay(_cachedEvents);
                  }

                  final birthdays = _groupBirthdays();

                  return Column(
                    children: [
                      _buildCalendar(_cachedGrouped, birthdays, primaryColor, theme),
                      const SizedBox(height: 4),
                      Expanded(
                        child: _buildEventList(
                          _eventsForDay(_selectedDay, _cachedGrouped),
                          _birthdaysForDay(_selectedDay, birthdays),
                          isAdmin,
                          theme,
                          primaryColor,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: isAdmin
            ? FloatingActionButton(
                heroTag: 'agenda_fab',
                onPressed: () => _showEventModal(context),
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, size: 28),
              )
            : null,
      ),
    );
  }

  // ─── Calendar ───

  Widget _buildCalendar(
    Map<DateTime, List<ChurchEvent>> grouped,
    Map<DateTime, List<_Birthday>> birthdays,
    Color primaryColor,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TableCalendar<ChurchEvent>(
        locale: 'pt_BR',
        firstDay: DateTime(2024),
        lastDay: DateTime(2030),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: _calendarFormat,
        startingDayOfWeek: StartingDayOfWeek.sunday,
        daysOfWeekHeight: 32,
        rowHeight: 48,
        availableGestures: AvailableGestures.all,
        availableCalendarFormats: const {
          CalendarFormat.month: 'Mês',
          CalendarFormat.week: 'Semana',
        },
        eventLoader: (day) => _eventsForDay(day, grouped),
        onDaySelected: _onDaySelected,
        onFormatChanged: (format) {
          setState(() => _calendarFormat = format);
        },
        onPageChanged: (focused) {
          _focusedDay = focused;
        },
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          leftChevronIcon: Icon(
            Icons.chevron_left,
            color: primaryColor,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            color: primaryColor,
          ),
          headerPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[400],
          ),
          weekendStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[400],
          ),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          cellMargin: const EdgeInsets.all(4),
          todayDecoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          selectedDecoration: BoxDecoration(
            color: primaryColor,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          defaultTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          weekendTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          // Hide default markers — we use custom builders
          markersMaxCount: 0,
        ),
        calendarBuilders: CalendarBuilders<ChurchEvent>(
          markerBuilder: (context, day, events) {
            final hasBirthday = birthdays[_normalizeDay(day)]?.isNotEmpty ?? false;
            final hasEvent = events.isNotEmpty;
            if (!hasEvent && !hasBirthday) return null;

            final isSelected = isSameDay(_selectedDay, day);
            final isToday = isSameDay(day, DateTime.now());

            Color eventDotColor = isSelected
                ? Colors.white
                : isToday
                    ? primaryColor
                    : primaryColor.withValues(alpha: 0.7);

            const birthdayColor = Color(0xFFFF7675);

            final dots = <Widget>[];
            if (hasEvent) {
              dots.add(Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: eventDotColor,
                  shape: BoxShape.circle,
                ),
              ));
            }
            if (hasBirthday) {
              dots.add(Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : birthdayColor,
                  shape: BoxShape.circle,
                ),
              ));
            }

            return Positioned(
              bottom: 9,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: dots,
              ),
            );
          },
        ),
      ),
    );
  }

  // ─── Event list ───

  Widget _buildEventList(
    List<ChurchEvent> dayEvents,
    List<_Birthday> dayBirthdays,
    bool isAdmin,
    ThemeData theme,
    Color primaryColor,
  ) {
    final totalItems = dayEvents.length + dayBirthdays.length;

    if (totalItems == 0) {
      return Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Column(
            key: const ValueKey('empty'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_busy_outlined, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(
                'Nenhum evento neste dia',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Key changes when day changes, triggering fresh animations
    final dayKey = ValueKey(
        '${_selectedDay.year}-${_selectedDay.month}-${_selectedDay.day}');

    return ListView.separated(
      key: dayKey,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: totalItems,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final child = i < dayBirthdays.length
            ? _buildBirthdayCard(dayBirthdays[i], theme)
            : _buildEventCard(
                dayEvents[i - dayBirthdays.length], isAdmin, theme, primaryColor);

        // Staggered delay: each card enters 60ms after the previous
        final delay = Duration(milliseconds: 60 * i);
        return _StaggeredFadeSlide(
          key: ValueKey('${dayKey.value}_$i'),
          delay: delay,
          child: child,
        );
      },
    );
  }

  Widget _buildBirthdayCard(_Birthday birthday, ThemeData theme) {
    const birthdayColor = Color(0xFFFF7675);
    final age = _focusedDay.year - birthday.date.year;

    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: birthdayColor.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: birthdayColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.cake_outlined, color: birthdayColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    birthday.name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    age > 0 ? 'Aniversário · $age anos' : 'Aniversário',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(
    ChurchEvent event,
    bool isAdmin,
    ThemeData theme,
    Color primaryColor,
  ) {
    final now = DateTime.now();
    final isToday = _normalizeDay(event.dateTime) == _normalizeDay(now);
    final isFuture = event.dateTime.isAfter(now);
    final iconColor = (isToday || isFuture) ? primaryColor : Colors.grey;

    final hour =
        '${event.dateTime.hour.toString().padLeft(2, '0')}:${event.dateTime.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () => _showEventDetail(event, isAdmin),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isToday ? primaryColor.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.event_rounded, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 13, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        hour,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey[500]),
                      ),
                      if (event.location.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Icon(Icons.location_on_outlined,
                            size: 13, color: Colors.grey[500]),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            event.location,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[500]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isAdmin)
              IconButton(
                icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
                onPressed: () => _showAdminActions(event),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              )
            else
              Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  // ─── Event detail bottom sheet ───

  void _showEventDetail(ChurchEvent event, bool isAdmin) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final hour =
        '${event.dateTime.hour.toString().padLeft(2, '0')}:${event.dateTime.minute.toString().padLeft(2, '0')}';
    final day =
        '${event.dateTime.day.toString().padLeft(2, '0')}/${event.dateTime.month.toString().padLeft(2, '0')}/${event.dateTime.year}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.event_rounded, size: 28, color: primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              event.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _detailRow(Icons.calendar_today_outlined, day, theme),
            const SizedBox(height: 12),
            _detailRow(Icons.access_time, hour, theme),
            if (event.location.isNotEmpty) ...[
              const SizedBox(height: 12),
              _detailRow(Icons.location_on_outlined, event.location, theme),
            ],
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  event.description,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
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
                child: const Text('Fechar'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[500]),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF2D3436),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Admin actions ───

  void _showAdminActions(ChurchEvent event) {
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
            const SizedBox(height: 20),
            _actionTile(
              icon: Icons.edit_outlined,
              label: 'Editar evento',
              color: Theme.of(ctx).colorScheme.primary,
              onTap: () {
                Navigator.pop(ctx);
                _showEventModal(context, event: event);
              },
            ),
            const SizedBox(height: 8),
            _actionTile(
              icon: Icons.delete_outline,
              label: 'Excluir evento',
              color: Theme.of(ctx).colorScheme.tertiary,
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteSheet(event);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Delete confirmation ───

  void _showDeleteSheet(ChurchEvent event) {
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
                color: Theme.of(ctx).colorScheme.tertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.delete_outline,
                size: 28,
                color: Theme.of(ctx).colorScheme.tertiary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Excluir evento',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Tem certeza que deseja excluir "${event.title}"?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
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
                    onPressed: () async {
                      await _service.deleteEvent(event.id);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Evento excluído')),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(ctx).colorScheme.tertiary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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

  // ─── Create / Edit event modal ───

  void _showEventModal(BuildContext ctx, {ChurchEvent? event}) {
    final isEdit = event != null;
    final titleCtrl = TextEditingController(text: event?.title ?? '');
    final locationCtrl = TextEditingController(text: event?.location ?? '');
    final descCtrl = TextEditingController(text: event?.description ?? '');
    DateTime selectedDate = event?.dateTime ?? DateTime.now();
    TimeOfDay selectedTime = event != null
        ? TimeOfDay(hour: event.dateTime.hour, minute: event.dateTime.minute)
        : TimeOfDay.now();
    bool saving = false;

    final theme = Theme.of(ctx);
    final primaryColor = theme.colorScheme.primary;

    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final dateTxt =
                '${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}';
            final timeTxt =
                '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

            return Padding(
              padding: EdgeInsets.fromLTRB(
                24, 28, 24, MediaQuery.of(modalCtx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
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
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        isEdit ? Icons.edit_outlined : Icons.event_rounded,
                        size: 28,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isEdit ? 'Editar evento' : 'Novo evento',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isEdit
                          ? 'Altere as informações do evento'
                          : 'Preencha as informações do evento',
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Título'),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: modalCtx,
                                initialDate: selectedDate,
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setModalState(() => selectedDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration:
                                  const InputDecoration(labelText: 'Data'),
                              child: Row(
                                children: [
                                  Expanded(child: Text(dateTxt)),
                                  Icon(Icons.calendar_today,
                                      size: 18, color: Colors.grey[500]),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: modalCtx,
                                initialTime: selectedTime,
                              );
                              if (picked != null) {
                                setModalState(() => selectedTime = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration:
                                  const InputDecoration(labelText: 'Hora'),
                              child: Row(
                                children: [
                                  Expanded(child: Text(timeTxt)),
                                  Icon(Icons.access_time,
                                      size: 18, color: Colors.grey[500]),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationCtrl,
                      decoration: const InputDecoration(labelText: 'Local'),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Descrição'),
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      minLines: 2,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(modalCtx),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              side: BorderSide(color: Colors.grey[300]!),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
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
                            onPressed: saving
                                ? null
                                : () async {
                                    final title = titleCtrl.text.trim();
                                    if (title.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('Informe o título do evento'),
                                        ),
                                      );
                                      return;
                                    }
                                    setModalState(() => saving = true);

                                    final dt = DateTime(
                                      selectedDate.year,
                                      selectedDate.month,
                                      selectedDate.day,
                                      selectedTime.hour,
                                      selectedTime.minute,
                                    );

                                    try {
                                      if (isEdit) {
                                        await _service.updateEvent(event.id, {
                                          'title': title,
                                          'dateTime': Timestamp.fromDate(dt),
                                          'location':
                                              locationCtrl.text.trim(),
                                          'description':
                                              descCtrl.text.trim(),
                                        });
                                      } else {
                                        final auth =
                                            context.read<AuthProvider>();
                                        final newEvent = ChurchEvent(
                                          id: '',
                                          title: title,
                                          dateTime: dt,
                                          location:
                                              locationCtrl.text.trim(),
                                          description:
                                              descCtrl.text.trim(),
                                          churchId: auth.churchId,
                                          createdBy:
                                              auth.appUser?.id ?? '',
                                          createdAt: DateTime.now(),
                                        );
                                        await _service.addEvent(newEvent);
                                      }

                                      if (modalCtx.mounted) {
                                        Navigator.pop(modalCtx);
                                      }
                                      if (mounted) {
                                        setState(
                                            () => _selectedDay = selectedDate);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(isEdit
                                                ? 'Evento atualizado'
                                                : 'Evento criado'),
                                          ),
                                        );
                                      }
                                    } catch (_) {
                                      setModalState(
                                          () => saving = false);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Erro ao salvar evento. Tente novamente.'),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(isEdit ? 'Salvar' : 'Criar'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Staggered fade + slide animation for agenda event cards.
class _StaggeredFadeSlide extends StatefulWidget {
  final Duration delay;
  final Widget child;

  const _StaggeredFadeSlide({
    super.key,
    required this.delay,
    required this.child,
  });

  @override
  State<_StaggeredFadeSlide> createState() => _StaggeredFadeSlideState();
}

class _StaggeredFadeSlideState extends State<_StaggeredFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _offset,
        child: widget.child,
      ),
    );
  }
}
