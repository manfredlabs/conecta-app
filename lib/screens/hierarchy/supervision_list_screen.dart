import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/hierarchy_provider.dart';
import '../../providers/cell_provider.dart';

class SupervisionListScreen extends StatelessWidget {
  const SupervisionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hierarchy = context.watch<HierarchyProvider>();
    final congregation = hierarchy.selectedCongregation;

    return Scaffold(
      appBar: AppBar(
        title: Text(congregation?.name ?? 'Supervisões'),
      ),
      body: _buildList(context, hierarchy),
    );
  }

  Widget _buildList(BuildContext context, HierarchyProvider hierarchy) {
    final supervisions = hierarchy.supervisions;

    if (supervisions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.workspaces_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Nenhuma supervisão encontrada',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: supervisions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final supervision = supervisions[index];
        return Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              hierarchy.selectSupervision(supervision);
              final cellProvider = context.read<CellProvider>();
              cellProvider.listenToCells(supervisionId: supervision.id, churchId: supervision.churchId);
              Navigator.pushNamed(context, '/supervision-hub');
            },
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
                          .secondary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_balance_rounded,
                      color: Theme.of(context).colorScheme.secondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          supervision.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          supervision.supervisorName ??
                              'Sem supervisor definido',
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
      },
    );
  }
}
