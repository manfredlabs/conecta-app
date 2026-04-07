import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/hierarchy_provider.dart';

class EditSupervisionScreen extends StatefulWidget {
  const EditSupervisionScreen({super.key});

  @override
  State<EditSupervisionScreen> createState() => _EditSupervisionScreenState();
}

class _EditSupervisionScreenState extends State<EditSupervisionScreen> {
  final _nameController = TextEditingController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final supervision =
          context.read<HierarchyProvider>().selectedSupervision;
      if (supervision != null) {
        _nameController.text = supervision.name.startsWith('Supervisão ')
            ? supervision.name.substring(11)
            : supervision.name;
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final suffix = _nameController.text.trim();
    if (suffix.isEmpty) return;

    final hierarchy = context.read<HierarchyProvider>();
    final supervision = hierarchy.selectedSupervision;
    if (supervision == null) return;

    final fullName = 'Supervisão $suffix';

    await hierarchy.updateSupervision(supervision.id, {
      'name': fullName,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supervisão atualizada!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Supervisão')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nome da supervisão',
                prefixIcon: const Icon(Icons.account_balance_outlined),
                prefixText: 'Supervisão ',
                prefixStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),

            const SizedBox(height: 32),

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
