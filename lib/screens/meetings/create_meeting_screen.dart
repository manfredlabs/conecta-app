import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cell_provider.dart';
import '../../models/cell_member_model.dart';
import '../../models/person_model.dart';
import '../../models/meeting_model.dart';
import '../../utils/role_colors.dart';

class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _dateExpanded = false;
  final Set<String> _presentMemberIds = {};
  final _observationsController = TextEditingController();

  @override
  void dispose() {
    _observationsController.dispose();
    super.dispose();
  }

  void _addVisitor() async {
    final visitor = await Navigator.pushNamed(context, '/add-visitor');
    if (!mounted) return;
    if (visitor != null && visitor is Visitor) {
      final cellProvider = context.read<CellProvider>();
      final cell = cellProvider.selectedCell!;

      final person = Person(
        id: '',
        name: visitor.name,
        congregationId: cell.congregationId,
        churchId: cell.churchId,
        gender: visitor.gender,
        baptized: visitor.baptized,
        birthDate: visitor.birthDate,
      );

      final auth = context.read<AuthProvider>();
      final userId = auth.appUser?.id ?? '';
      final cmId = await cellProvider.addPersonAndCellMember(
        person: person,
        cellId: cell.id,
        supervisionId: cell.supervisionId,
        congregationId: cell.congregationId,
        churchId: auth.churchId,
        isVisitor: true,
        changedBy: userId,
      );
      if (cmId != null && mounted) {
        setState(() {
          _presentMemberIds.add(cmId);
        });
      }
    }
  }

  Future<void> _save() async {
    // Validar presença mínima
    if (_presentMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos 1 membro presente.'),
        ),
      );
      return;
    }

    final cellProvider = context.read<CellProvider>();
    final authProvider = context.read<AuthProvider>();
    final cell = cellProvider.selectedCell!;

    // Validar data duplicada
    final hasDuplicate = cellProvider.meetings.any((m) =>
        m.date.year == _selectedDate.year &&
        m.date.month == _selectedDate.month &&
        m.date.day == _selectedDate.day);

    if (hasDuplicate) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Já existe uma reunião registrada nesta data.'),
        ),
      );
      return;
    }

    final memberRoles = {
      for (final m in cellProvider.cellMembers.where((m) => m.isActive))
        m.id: m.isLeader
            ? 'leader'
            : m.isHelper
                ? 'helper'
                : m.isVisitor
                    ? 'visitor'
                    : 'member',
    };

    final meeting = Meeting(
      id: '',
      cellId: cell.id,
      supervisionId: cell.supervisionId,
      congregationId: cell.congregationId,
      date: _selectedDate,
      presentMemberIds: _presentMemberIds.toList(),
      memberRoles: memberRoles,
      visitors: const [],
      observations: _observationsController.text.trim().isEmpty
          ? null
          : _observationsController.text.trim(),
      createdBy: authProvider.appUser!.id,
    );

    await cellProvider.addMeeting(meeting);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reunião registrada!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Reunião')),
      body: Consumer<CellProvider>(
        builder: (context, cellProvider, _) {
          final members = List<CellMember>.from(
            cellProvider.cellMembers.where((m) => m.isActive),
          )..sort((a, b) {
              int priority(CellMember m) =>
                  m.isLeader ? 0 : m.isHelper ? 1 : m.isVisitor ? 3 : 2;
              final p = priority(a).compareTo(priority(b));
              if (p != 0) return p;
              return a.name.compareTo(b.name);
            });

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    // ── Data da Reunião ──
                    Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () =>
                            setState(() => _dateExpanded = !_dateExpanded),
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
                                child: Icon(Icons.calendar_today_rounded,
                                    color: primaryColor, size: 22),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Data da Reunião',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(color: Colors.grey[500]),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                _dateExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: CalendarDatePicker(
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          onDateChanged: (date) {
                            setState(() {
                              _selectedDate = date;
                              _dateExpanded = false;
                            });
                          },
                        ),
                      ),
                      crossFadeState: _dateExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                    ),

                    const SizedBox(height: 20),

                    // ── Presença ──
                    Row(
                      children: [
                        Text(
                          'Presença',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_presentMemberIds.length}/${members.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _addVisitor,
                          icon: const Icon(Icons.person_add_rounded, size: 18),
                          label: const Text('Visitante'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (members.isEmpty)
                      Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(Icons.people_outline,
                                  size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                'Nenhum membro cadastrado',
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      // Select all
                      _buildSelectAllRow(members),
                      const SizedBox(height: 8),
                      // Member list
                      ...members.asMap().entries.expand((entry) => [
                        if (entry.key > 0) const SizedBox(height: 8),
                        _buildMemberTile(entry.value),
                      ]),
                    ],

                    const SizedBox(height: 20),

                    // ── Observações ──
                    Text(
                      'Observações',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextFormField(
                          controller: _observationsController,
                          maxLines: 4,
                          minLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText:
                                'Pedidos de oração, testemunhos, observações...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[400],
                            ),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
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
                    onPressed: cellProvider.isLoading ? null : _save,
                    icon: cellProvider.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text(
                      'Salvar Reunião',
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
          );
        },
      ),
    );
  }

  Widget _buildSelectAllRow(List<CellMember> members) {
    final allSelected =
        members.isNotEmpty && _presentMemberIds.length == members.length;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      color: primaryColor.withValues(alpha: 0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primaryColor.withValues(alpha: 0.15)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            if (allSelected) {
              _presentMemberIds.clear();
            } else {
              _presentMemberIds.addAll(members.map((m) => m.id));
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                allSelected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: primaryColor,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                'Selecionar todos',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberTile(CellMember member) {
    final isPresent = _presentMemberIds.contains(member.id);
    final roleColor = RoleColors.forMember(
      theme: Theme.of(context),
      isLeader: member.isLeader,
      isHelper: member.isHelper,
      isVisitor: member.isVisitor,
    );
    final cell = context.read<CellProvider>().selectedCell;
    final roleLabel = RoleColors.roleLabel(member, mainLeaderId: cell?.leaderId);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            if (isPresent) {
              _presentMemberIds.remove(member.id);
            } else {
              _presentMemberIds.add(member.id);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isPresent ? roleColor : Colors.grey)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    member.name.isNotEmpty
                        ? member.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: isPresent ? roleColor : Colors.grey[400],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: isPresent ? null : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isPresent ? roleColor : Colors.grey)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPresent ? roleColor : Colors.grey[400],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isPresent
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: isPresent
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[300],
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
