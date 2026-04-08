import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cell_provider.dart';
import '../../models/cell_model.dart';

class CongregationCellsScreen extends StatefulWidget {
  const CongregationCellsScreen({super.key});

  @override
  State<CongregationCellsScreen> createState() =>
      _CongregationCellsScreenState();
}

class _CongregationCellsScreenState extends State<CongregationCellsScreen> {
  final _db = FirebaseFirestore.instance;
  Map<String, String> _supervisionNames = {};
  List<CellGroup> _cells = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final user = context.read<AuthProvider>().appUser;
    if (user == null || user.congregationId == null) return;

    final supsSnap = await _db
        .collection('supervisions')
        .where('congregationId', isEqualTo: user.congregationId)
        .get();
    final supNames = <String, String>{};
    for (final doc in supsSnap.docs) {
      supNames[doc.id] = doc.data()['name'] ?? '';
    }

    final cellsSnap = await _db
        .collection('cells')
        .where('congregationId', isEqualTo: user.congregationId)
        .get();
    final cells = cellsSnap.docs.map((d) => CellGroup.fromFirestore(d)).toList()
      ..sort((a, b) {
        final supCmp = (supNames[a.supervisionId] ?? '')
            .compareTo(supNames[b.supervisionId] ?? '');
        if (supCmp != 0) return supCmp;
        return a.name.compareTo(b.name);
      });

    if (mounted) {
      setState(() {
        _supervisionNames = supNames;
        _cells = cells;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Células da Congregação')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cells.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_off, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhuma célula encontrada',
                        style: TextStyle(color: Colors.grey[400], fontSize: 16),
                      ),
                    ],
                  ),
                )
              : _buildGroupedList(),
    );
  }

  Widget _buildGroupedList() {
    // Group cells by supervision
    final grouped = <String, List<CellGroup>>{};
    for (final cell in _cells) {
      grouped.putIfAbsent(cell.supervisionId, () => []).add(cell);
    }

    // Sort supervision keys by name
    final sortedSupIds = grouped.keys.toList()
      ..sort((a, b) =>
          (_supervisionNames[a] ?? '').compareTo(_supervisionNames[b] ?? ''));

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: sortedSupIds.length,
      itemBuilder: (context, index) {
        final supId = sortedSupIds[index];
        final supName = _supervisionNames[supId] ?? 'Supervisão';
        final cells = grouped[supId]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Text(
                supName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
              ),
            ),
            ...cells.asMap().entries.expand((entry) => [
              if (entry.key > 0) const SizedBox(height: 8),
              _CellCard(
                cell: entry.value,
                onTap: () {
                  context.read<CellProvider>().selectCell(entry.value);
                  Navigator.pushNamed(context, '/cell-hub');
                },
              ),
            ]),
          ],
        );
      },
    );
  }
}

class _CellCard extends StatelessWidget {
  final CellGroup cell;
  final VoidCallback onTap;

  const _CellCard({required this.cell, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.groups_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cell.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cell.leaderName ?? 'Sem líder',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey[500]),
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
