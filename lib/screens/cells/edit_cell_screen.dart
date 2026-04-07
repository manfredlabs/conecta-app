import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cell_provider.dart';

class EditCellScreen extends StatefulWidget {
  const EditCellScreen({super.key});

  @override
  State<EditCellScreen> createState() => _EditCellScreenState();
}

class _EditCellScreenState extends State<EditCellScreen> {
  final _nameController = TextEditingController();
  String? _selectedDay;
  int _hour = 19;
  int _minute = 30;
  bool _timeExpanded = false;
  bool _initialized = false;

  static const _weekDays = [
    ('Seg', 'Segunda'),
    ('Ter', 'Terça'),
    ('Qua', 'Quarta'),
    ('Qui', 'Quinta'),
    ('Sex', 'Sexta'),
    ('Sáb', 'Sábado'),
    ('Dom', 'Domingo'),
  ];

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final cell = context.read<CellProvider>().selectedCell;
      if (cell != null) {
        _nameController.text = cell.name.startsWith('Célula ')
            ? cell.name.substring(7)
            : cell.name;
        _selectedDay = cell.meetingDay;
        if (cell.meetingTime != null) {
          final parts = cell.meetingTime!.split(':');
          if (parts.length == 2) {
            _hour = int.tryParse(parts[0]) ?? 19;
            _minute = int.tryParse(parts[1]) ?? 30;
          }
        }
      }
      _hourController = FixedExtentScrollController(initialItem: _hour);
      _minuteController = FixedExtentScrollController(initialItem: _minute ~/ 5);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final suffix = _nameController.text.trim();
    if (suffix.isEmpty) return;

    final cellProvider = context.read<CellProvider>();
    final cell = cellProvider.selectedCell;
    if (cell == null) return;

    final fullName = 'Célula $suffix';
    final timeStr = '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

    await cellProvider.updateCell(cell.id, {
      'name': fullName,
      'meetingDay': _selectedDay,
      'meetingTime': timeStr,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Célula atualizada!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Célula')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nome
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nome da célula',
                prefixIcon: const Icon(Icons.groups_outlined),
                prefixText: 'Célula ',
                prefixStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Dia da reunião
            Text(
              'Dia da reunião',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _weekDays.map((day) {
                final (abbr, full) = day;
                final selected = _selectedDay == full;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDay = selected ? null : full);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? theme.colorScheme.primary
                            : Colors.grey[300]!,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        abbr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Horário
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.access_time_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Horário da reunião'),
                    subtitle: Text(
                      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    trailing: Icon(
                      _timeExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey[400],
                    ),
                    onTap: () => setState(() => _timeExpanded = !_timeExpanded),
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: SizedBox(
                      height: 150,
                      child: Row(
                        children: [
                          Expanded(
                            child: ListWheelScrollView.useDelegate(
                              controller: _hourController,
                              itemExtent: 40,
                              physics: const FixedExtentScrollPhysics(),
                              diameterRatio: 1.5,
                              onSelectedItemChanged: (index) {
                                setState(() => _hour = index);
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 24,
                                builder: (context, index) {
                                  final isSelected = index == _hour;
                                  return Center(
                                    child: Text(
                                      index.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        fontSize: isSelected ? 22 : 16,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : Colors.grey[400],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          Text(
                            ':',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          Expanded(
                            child: ListWheelScrollView.useDelegate(
                              controller: _minuteController,
                              itemExtent: 40,
                              physics: const FixedExtentScrollPhysics(),
                              diameterRatio: 1.5,
                              onSelectedItemChanged: (index) {
                                setState(() => _minute = index * 5);
                              },
                              childDelegate: ListWheelChildBuilderDelegate(
                                childCount: 12,
                                builder: (context, index) {
                                  final value = index * 5;
                                  final isSelected = value == _minute;
                                  return Center(
                                    child: Text(
                                      value.toString().padLeft(2, '0'),
                                      style: TextStyle(
                                        fontSize: isSelected ? 22 : 16,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : Colors.grey[400],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    crossFadeState: _timeExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Salvar
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Salvar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
