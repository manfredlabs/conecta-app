import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/hierarchy_provider.dart';

class EditCongregationScreen extends StatefulWidget {
  const EditCongregationScreen({super.key});

  @override
  State<EditCongregationScreen> createState() => _EditCongregationScreenState();
}

class _EditCongregationScreenState extends State<EditCongregationScreen> {
  final _nameController = TextEditingController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final congregation =
          context.read<HierarchyProvider>().selectedCongregation;
      if (congregation != null) {
        _nameController.text = congregation.name.startsWith('Congregação ')
            ? congregation.name.substring(12)
            : congregation.name;
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
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final hierarchy = context.read<HierarchyProvider>();
    final congregation = hierarchy.selectedCongregation;
    if (congregation == null) return;

    final fullName = 'Congregação $name';

    await hierarchy.updateCongregation(congregation.id, {
      'name': fullName,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Congregação atualizada!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Congregação')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nome da congregação',
                prefixIcon: const Icon(Icons.account_balance_outlined),
                prefixText: 'Congregação ',
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
