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
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Célula')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                // ── Nome ──
                Text(
                  'Nome',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        prefixText: 'Célula ',
                        prefixStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: primaryColor,
                        ),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Dia da reunião ──
                Text(
                  'Dia da reunião',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
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
                              ? primaryColor
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? primaryColor
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

                const SizedBox(height: 20),

                // ── Horário ──
                Text(
                  'Horário',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _timeExpanded = !_timeExpanded),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.access_time_rounded,
                                    color: primaryColor, size: 22),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Horário da reunião',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: Colors.grey[500]),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                _timeExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
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
                                                ? primaryColor
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
                                  color: primaryColor,
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
                                                ? primaryColor
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

                const SizedBox(height: 24),
              ],
            ),
          ),

          // ── Botão Salvar (fixo no bottom) ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                top: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: const Text(
                  'Salvar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
