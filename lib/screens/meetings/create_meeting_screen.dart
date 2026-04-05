import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cell_provider.dart';
import '../../models/member_model.dart';
import '../../models/meeting_model.dart';

class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  DateTime _selectedDate = DateTime.now();
  final Set<String> _presentMemberIds = {};
  final List<Visitor> _visitors = [];
  final _observationsController = TextEditingController();

  @override
  void dispose() {
    _observationsController.dispose();
    super.dispose();
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _addVisitor() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar Visitante'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nome',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefone (opcional)',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                setState(() {
                  _visitors.add(Visitor(
                    name: nameController.text.trim(),
                    phone: phoneController.text.trim().isEmpty
                        ? null
                        : phoneController.text.trim(),
                  ));
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final cellProvider = context.read<CellProvider>();
    final authProvider = context.read<AuthProvider>();
    final cell = cellProvider.selectedCell!;

    final meeting = Meeting(
      id: '',
      cellId: cell.id,
      supervisionId: cell.supervisionId,
      congregationId: cell.congregationId,
      date: _selectedDate,
      presentMemberIds: _presentMemberIds.toList(),
      visitors: _visitors,
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
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Reunião')),
      body: Consumer<CellProvider>(
        builder: (context, cellProvider, _) {
          final members = cellProvider.members;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date picker
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Data da Reunião'),
                    subtitle: Text(
                      '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: _selectDate,
                  ),
                ),

                const SizedBox(height: 16),

                // Members presence
                Text(
                  'Presença dos Membros (${_presentMemberIds.length}/${members.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),

                if (members.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Nenhum membro cadastrado. Adicione membros primeiro.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  _buildSelectAllRow(members),

                ...members.map((member) => _buildMemberCheckbox(member)),

                const SizedBox(height: 16),

                // Visitors
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Visitantes (${_visitors.length})',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    TextButton.icon(
                      onPressed: _addVisitor,
                      icon: const Icon(Icons.person_add),
                      label: const Text('Adicionar'),
                    ),
                  ],
                ),
                ..._visitors.asMap().entries.map((entry) {
                  final i = entry.key;
                  final v = entry.value;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      title: Text(v.name),
                      subtitle: v.phone != null ? Text(v.phone!) : null,
                      trailing: IconButton(
                        icon:
                            const Icon(Icons.close, color: Colors.red),
                        onPressed: () {
                          setState(() => _visitors.removeAt(i));
                        },
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 16),

                // Observations
                TextFormField(
                  controller: _observationsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Observações (opcional)',
                    prefixIcon: Icon(Icons.notes),
                    alignLabelWithHint: true,
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
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Salvar Reunião'),
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

  Widget _buildSelectAllRow(List<Member> members) {
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

  Widget _buildMemberCheckbox(Member member) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: CheckboxListTile(
        title: Text(member.name),
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
