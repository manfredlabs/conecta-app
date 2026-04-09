import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cell_provider.dart';
import '../../providers/hierarchy_provider.dart';
import '../../models/user_model.dart';
import '../../models/supervision_model.dart';

class CellsTab extends StatefulWidget {
  const CellsTab({super.key});

  @override
  State<CellsTab> createState() => _CellsTabState();
}

class _CellsTabState extends State<CellsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final auth = context.read<AuthProvider>();
    final user = auth.appUser;
    if (user == null) return;

    switch (user.role) {
      case UserRole.admin:
        context.read<HierarchyProvider>().listenToCongregations(churchId: auth.churchId);
        break;
      case UserRole.pastor:
        context.read<CellProvider>().listenToCells(
              congregationId: user.congregationId,
            );
        break;
      case UserRole.supervisor:
        context.read<CellProvider>().listenToCells(
              supervisionId: user.supervisionId,
            );
        _loadSupervision(user.supervisionId);
        break;
      case UserRole.leader:
        context.read<CellProvider>().listenToCells(leaderId: user.id);
        break;
    }
  }

  Future<void> _loadSupervision(String? supervisionId) async {
    if (supervisionId == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('supervisions')
        .doc(supervisionId)
        .get();
    if (!mounted || !doc.exists) return;
    final supervision = Supervision.fromFirestore(doc);
    context.read<HierarchyProvider>().selectSupervision(supervision);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.appUser;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Text(
              'Células',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          Expanded(child: _buildContent(user)),
        ],
      ),
    );
  }

  Widget _buildContent(AppUser user) {
    switch (user.role) {
      case UserRole.admin:
        return _buildCongregationList();
      case UserRole.pastor:
        return _buildCellList();
      case UserRole.supervisor:
        return _buildCellList();
      case UserRole.leader:
        return _buildCellList();
    }
  }

  Widget _buildCongregationList() {
    return Consumer<HierarchyProvider>(
      builder: (context, hierarchy, _) {
        final congregations = hierarchy.congregations;
        if (congregations.isEmpty) {
          return _emptyState(Icons.account_balance_outlined, 'Nenhuma congregação encontrada');
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: congregations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final c = congregations[index];
            return _HierarchyCard(
              icon: Icons.account_balance_rounded,
              iconColor: Theme.of(context).colorScheme.tertiary,
              title: c.name,
              subtitle: c.pastorName ?? 'Sem pastor',
              onTap: () {
                hierarchy.selectCongregation(c);
                Navigator.pushNamed(context, '/supervision-list');
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCellList() {
    final user = context.read<AuthProvider>().appUser;
    return Consumer<CellProvider>(
      builder: (context, cellProvider, _) {
        final cells = List.from(cellProvider.cells);
        if (cells.isEmpty) {
          return _emptyState(Icons.groups_outlined, 'Nenhuma célula encontrada');
        }
        // Célula do usuário primeiro
        if (user?.cellId != null) {
          cells.sort((a, b) {
            if (a.id == user!.cellId) return -1;
            if (b.id == user.cellId) return 1;
            return a.name.compareTo(b.name);
          });
        }
        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: cells.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final cell = cells[index];
            final isMyCell = user?.cellId != null && cell.id == user!.cellId;
            return _HierarchyCard(
              icon: Icons.groups_rounded,
              iconColor: isMyCell
                  ? Colors.green
                  : Theme.of(context).colorScheme.primary,
              title: cell.name,
              subtitle: isMyCell
                  ? 'Minha célula · ${cell.leaderName ?? 'Sem líder'}'
                  : cell.leaderName ?? 'Sem líder',
              highlighted: isMyCell,
              onTap: () {
                cellProvider.selectCell(cell);
                Navigator.pushNamed(context, '/cell-hub');
              },
            );
          },
        );
      },
    );
  }

  Widget _emptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _HierarchyCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  const _HierarchyCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: highlighted
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: iconColor.withValues(alpha: 0.4), width: 1.5),
            )
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: highlighted ? iconColor.withValues(alpha: 0.03) : null,
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
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
