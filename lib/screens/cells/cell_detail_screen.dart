import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cell_provider.dart';
import '../../models/member_model.dart';

class CellDetailScreen extends StatelessWidget {
  const CellDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CellProvider>(
      builder: (context, cellProvider, _) {
        final cell = cellProvider.selectedCell;
        if (cell == null) {
          return const Scaffold(
            body: Center(child: Text('Nenhuma célula selecionada')),
          );
        }

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(cell.name),
              bottom: const TabBar(
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(icon: Icon(Icons.people), text: 'Membros'),
                  Tab(icon: Icon(Icons.event), text: 'Reuniões'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _MembersTab(cellProvider: cellProvider),
                _MeetingsTab(cellProvider: cellProvider),
              ],
            ),
            floatingActionButton: Builder(
              builder: (ctx) {
                final tabIndex = DefaultTabController.of(ctx).index;
                return FloatingActionButton(
                  onPressed: () {
                    if (tabIndex == 0) {
                      Navigator.pushNamed(context, '/add-member');
                    } else {
                      Navigator.pushNamed(context, '/create-meeting');
                    }
                  },
                  child: const Icon(Icons.add),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _MembersTab extends StatelessWidget {
  final CellProvider cellProvider;
  const _MembersTab({required this.cellProvider});

  @override
  Widget build(BuildContext context) {
    final members = cellProvider.members;

    if (members.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_add, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Nenhum membro cadastrado',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Toque no + para adicionar',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        return _MemberCard(member: member, cellProvider: cellProvider);
      },
    );
  }
}

class _MemberCard extends StatelessWidget {
  final Member member;
  final CellProvider cellProvider;
  const _MemberCard({required this.member, required this.cellProvider});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(member.name[0].toUpperCase()),
        ),
        title: Text(member.name),
        subtitle: member.phone != null ? Text(member.phone!) : null,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _confirmDelete(context),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover membro'),
        content: Text('Deseja remover ${member.name} da célula?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              cellProvider.deleteMember(member.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }
}

class _MeetingsTab extends StatelessWidget {
  final CellProvider cellProvider;
  const _MeetingsTab({required this.cellProvider});

  @override
  Widget build(BuildContext context) {
    final meetings = cellProvider.meetings;

    if (meetings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Nenhuma reunião registrada',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Toque no + para registrar',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: meetings.length,
      itemBuilder: (context, index) {
        final meeting = meetings[index];
        final dateStr =
            '${meeting.date.day.toString().padLeft(2, '0')}/${meeting.date.month.toString().padLeft(2, '0')}/${meeting.date.year}';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.event, color: Colors.white),
            ),
            title: Text(dateStr),
            subtitle: Text(
              '${meeting.presentMemberIds.length} membros • ${meeting.visitors.length} visitantes',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.pushNamed(context, '/meeting-detail',
                  arguments: meeting);
            },
          ),
        );
      },
    );
  }
}
