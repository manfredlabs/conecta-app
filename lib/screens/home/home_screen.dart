import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cell_provider.dart';
import '../../models/user_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final auth = context.read<AuthProvider>();
    final cellProvider = context.read<CellProvider>();
    final user = auth.appUser;
    if (user == null) return;

    switch (user.role) {
      case UserRole.admin:
        cellProvider.listenToCells();
        break;
      case UserRole.pastor:
        cellProvider.listenToCells(congregationId: user.congregationId);
        break;
      case UserRole.supervisor:
        cellProvider.listenToCells(supervisionId: user.supervisionId);
        break;
      case UserRole.leader:
        cellProvider.listenToCells(leaderId: user.id);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.appUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conecta'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              auth.signOut().then((_) {
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildUserHeader(user),
          Expanded(child: _buildCellList()),
        ],
      ),
    );
  }

  Widget _buildUserHeader(AppUser user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Olá, ${user.name}!',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            user.roleDisplayName,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCellList() {
    return Consumer<CellProvider>(
      builder: (context, cellProvider, _) {
        final cells = cellProvider.cells;

        if (cells.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_off, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Nenhuma célula encontrada',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: cells.length,
          itemBuilder: (context, index) {
            final cell = cells[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.groups, color: Colors.white),
                ),
                title: Text(
                  cell.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(cell.leaderName ?? 'Sem líder definido'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  cellProvider.selectCell(cell);
                  Navigator.pushNamed(context, '/cell-detail');
                },
              ),
            );
          },
        );
      },
    );
  }
}
