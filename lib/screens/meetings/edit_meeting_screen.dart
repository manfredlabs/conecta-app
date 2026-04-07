import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cell_provider.dart';
import '../../models/cell_member_model.dart';
import '../../models/person_model.dart';
import '../../models/meeting_model.dart';

class EditMeetingScreen extends StatefulWidget {
  const EditMeetingScreen({super.key});

  @override
  State<EditMeetingScreen> createState() => _EditMeetingScreenState();
}

class _EditMeetingScreenState extends State<EditMeetingScreen> {
  late Meeting _meeting;
  late Set<String> _presentMemberIds;
  late TextEditingController _observationsController;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _meeting = ModalRoute.of(context)!.settings.arguments as Meeting;
      _presentMemberIds = Set<String>.from(_meeting.presentMemberIds);
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
      'presentMemberIds': _presentMemberIds.toList(),
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
        gender: visitor.gender,
        baptized: visitor.baptized,
        birthDate: visitor.birthDate,
      );

      final cmId = await cellProvider.addPersonAndCellMember(
        person: person,
        cellId: cell.id,
        supervisionId: cell.supervisionId,
        congregationId: cell.congregationId,
        isVisitor: true,
      );
      if (cmId != null && mounted) {
        setState(() {
          _presentMemberIds.add(cmId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final weekdays = [
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo',
    ];
    final weekday = weekdays[_meeting.date.weekday - 1];
    final dateStr =
        '${_meeting.date.day.toString().padLeft(2, '0')}/${_meeting.date.month.toString().padLeft(2, '0')}/${_meeting.date.year}';

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Reunião')),
      body: Consumer<CellProvider>(
        builder: (context, cellProvider, _) {
          final members =
              cellProvider.cellMembers.where((m) => m.isActive).toList()
                ..sort((a, b) {
                  int priority(CellMember m) => m.isLeader ? 0 : m.isHelper ? 1 : m.isVisitor ? 3 : 2;
                  return priority(a).compareTo(priority(b));
                });

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date (read-only)
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.calendar_today_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Data da Reunião'),
                    subtitle: Text(
                      '$weekday, $dateStr',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Presence
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Presença (${_presentMemberIds.length}/${members.length})',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addVisitor,
                        icon: const Icon(Icons.person_add, size: 20),
                        label: const Text('Novo Visitante'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                _buildSelectAllRow(members),

                ...members.map((member) => _buildMemberCheckbox(member)),

                const SizedBox(height: 16),

                // Observations
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: TextFormField(
                      controller: _observationsController,
                      maxLines: 4,
                      minLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText:
                            'Observações: pedidos de oração, testemunhos...',
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

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: cellProvider.isLoading ? null : _save,
                    icon: cellProvider.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Salvar Alterações'),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectAllRow(List<CellMember> members) {
    final allSelected = _presentMemberIds.length == members.length;
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
      child: CheckboxListTile(
        title: const Text(
          'Selecionar todos',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        value: allSelected,
        onChanged: (value) {
          setState(() {
            if (value == true) {
              _presentMemberIds.addAll(members.map((m) => m.id));
            } else {
              _presentMemberIds.clear();
            }
          });
        },
      ),
    );
  }

  Widget _buildMemberCheckbox(CellMember member) {
    final roleLabel = member.isLeader
        ? 'Líder'
        : member.isHelper
            ? 'Auxiliar'
            : member.isVisitor
                ? 'Visitante'
                : 'Membro';
    final roleColor = member.isLeader
        ? Theme.of(context).colorScheme.primary
        : member.isHelper
            ? Colors.teal
            : member.isVisitor
                ? Colors.orange
                : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: CheckboxListTile(
        title: Row(
          children: [
            Expanded(child: Text(member.name)),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                roleLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: roleColor,
                ),
              ),
            ),
          ],
        ),
        value: _presentMemberIds.contains(member.id),
        onChanged: (value) {
          setState(() {
            if (value == true) {
              _presentMemberIds.add(member.id);
            } else {
              _presentMemberIds.remove(member.id);
            }
          });
        },
      ),
    );
  }
}
