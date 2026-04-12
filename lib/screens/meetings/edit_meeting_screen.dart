import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cell_provider.dart';
import '../../models/cell_member_model.dart';
import '../../models/person_model.dart';
import '../../models/meeting_model.dart';
import '../../utils/role_colors.dart';
import '../../config/theme.dart';

class EditMeetingScreen extends StatefulWidget {
  const EditMeetingScreen({super.key});

  @override
  State<EditMeetingScreen> createState() => _EditMeetingScreenState();
}

class _EditMeetingScreenState extends State<EditMeetingScreen> {
  late Meeting _meeting;
  late DateTime _selectedDate;
  bool _dateExpanded = false;
  late Set<String> _presentMemberIds;
  late Map<String, String> _memberRoles;
  late TextEditingController _observationsController;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _meeting = ModalRoute.of(context)!.settings.arguments as Meeting;
      _selectedDate = _meeting.date;
      _presentMemberIds = Set<String>.from(_meeting.presentMemberIds);
      _memberRoles = Map<String, String>.from(_meeting.memberRoles);
      _observationsController =
          TextEditingController(text: _meeting.observations ?? '');
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _observationsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cellProvider = context.read<CellProvider>();

    await cellProvider.updateMeeting(_meeting.id, {
      'date': Timestamp.fromDate(_selectedDate),
      'presentMemberIds': _presentMemberIds.toList(),
      'memberRoles': _memberRoles,
      'observations': _observationsController.text.trim().isEmpty
          ? null
          : _observationsController.text.trim(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reunião atualizada!')),
      );
      Navigator.pop(context, true);
    }
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
          _memberRoles[cmId] = 'visitor';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    final dateStr =
        '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}';

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Reunião')),
      body: Consumer<CellProvider>(
        builder: (context, cellProvider, _) {
          // Use local snapshot (includes newly added visitors)
          final List<CellMember> members;
          if (_memberRoles.isNotEmpty) {
            members = List<CellMember>.from(
              cellProvider.cellMembers.where(
                  (m) => _memberRoles.containsKey(m.id)),
            );
          } else {
            members = List<CellMember>.from(
              cellProvider.cellMembers.where((m) => m.isActive),
            );
          }
          members.sort((a, b) {
              int priority(String role) {
                switch (role) {
                  case 'leader': return 0;
                  case 'helper': return 1;
                  case 'visitor': return 3;
                  default: return 2;
                }
              }
              int currentPriority(CellMember m) =>
                  m.isLeader ? 0 : m.isHelper ? 1 : m.isVisitor ? 3 : 2;

              final pa = _memberRoles.containsKey(a.id)
                  ? priority(_memberRoles[a.id]!)
                  : currentPriority(a);
              final pb = _memberRoles.containsKey(b.id)
                  ? priority(_memberRoles[b.id]!)
                  : currentPriority(b);
              final p = pa.compareTo(pb);
              if (p != 0) return p;
              return a.name.compareTo(b.name);
            });

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  children: [
                    // ── Data ──
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          InkWell(
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
                                              ?.copyWith(color: AppColors.neutral500),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          dateStr,
                                          style: theme.textTheme.titleMedium?.copyWith(
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
                                    color: AppColors.neutral400,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedCrossFade(
                            firstChild: const SizedBox.shrink(),
                            secondChild: Card(
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
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Presença ──
                    Row(
                      children: [
                        Text(
                          'Presença',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.neutral600,
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

                    _buildSelectAllRow(members),
                    const SizedBox(height: 4),
                    ...members.map((m) => _buildMemberTile(m)),

                    const SizedBox(height: 20),

                    // ── Observações ──
                    Text(
                      'Observações',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.neutral600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
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
                              color: AppColors.neutral400,
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
                    top: const BorderSide(color: AppColors.neutral200, width: 1),
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
                              color: AppColors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: const Text(
                      'Salvar Alterações',
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

    final cell = context.read<CellProvider>().selectedCell;
    // Use snapshot role if available
    final String snapshotRole = _memberRoles[member.id] ?? '';
    final Color roleColor;
    final String roleLabel;
    if (snapshotRole.isNotEmpty) {
      roleColor = RoleColors.forSnapshot(snapshotRole, Theme.of(context));
      if (snapshotRole == 'leader' && cell != null && cell.leaderId != null && member.person?.userId != null && member.person?.userId != cell.leaderId) {
        roleLabel = 'Co-líder';
      } else {
        roleLabel = snapshotRole == 'leader'
            ? 'Líder'
            : snapshotRole == 'helper'
                ? 'Auxiliar'
                : snapshotRole == 'visitor'
                    ? 'Visitante'
                    : 'Membro';
      }
    } else {
      roleColor = RoleColors.forMember(
        theme: Theme.of(context),
        isLeader: member.isLeader,
        isHelper: member.isHelper,
        isVisitor: member.isVisitor,
      );
      roleLabel = RoleColors.roleLabel(member, mainLeaderId: cell?.leaderId);
    }

    return Card(
      margin: const EdgeInsets.only(top: 6),
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
                  color: (isPresent ? roleColor : AppColors.neutral600)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Center(
                  child: Text(
                    member.name.isNotEmpty
                        ? member.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: isPresent ? roleColor : AppColors.neutral400,
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
                        color: isPresent ? null : AppColors.neutral500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isPresent ? roleColor : AppColors.neutral600)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isPresent ? roleColor : AppColors.neutral400,
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
                      : AppColors.neutral300,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
