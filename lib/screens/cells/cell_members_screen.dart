import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cell_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/permissions.dart';
import '../../models/cell_member_model.dart';

class CellMembersScreen extends StatelessWidget {
  const CellMembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CellProvider>(
      builder: (context, cellProvider, _) {
        final cell = cellProvider.selectedCell;
        final user = context.read<AuthProvider>().appUser;
        if (cell == null || user == null) {
          return const Scaffold(
            body: Center(child: Text('Nenhuma célula selecionada')),
          );
        }

        final canManage = Permissions.canManageMembers(user, cell);

        final allMembers = List<CellMember>.from(cellProvider.cellMembers)
          ..sort((a, b) {
            int priority(CellMember m) {
              if (m.isLeader) return 0;
              if (m.isHelper) return 1;
              if (!m.isVisitor) return 2;
              return 3;
            }
            final p = priority(a).compareTo(priority(b));
            if (p != 0) return p;
            return a.name.compareTo(b.name);
          });

        final activeMembers =
            allMembers.where((m) => m.isActive).toList();
        final inactiveMembers =
            allMembers.where((m) => !m.isActive).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Participantes'),
          ),
          body: allMembers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_add_outlined,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum participante cadastrado',
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 16),
                      ),
                      if (canManage) ...[
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/add-member'),
                          icon: const Icon(Icons.person_add_rounded, size: 18),
                          label: const Text('Adicionar'),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (canManage) ...[
                      Card(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                        elevation: 0,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () =>
                              Navigator.pushNamed(context, '/add-member'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.person_add_rounded,
                                      color: Theme.of(context).colorScheme.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Adicionar Participante',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                ),
                                const Spacer(),
                                Icon(Icons.chevron_right,
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.5)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ...activeMembers.map((member) => _MemberCard(
                          member: member,
                          canManage: canManage,
                          locked: member.isLeader && cell.leaderId == user.id,
                        )),
                    if (inactiveMembers.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 8),
                        child: Row(
                          children: [
                            Icon(Icons.person_off_outlined,
                                size: 18, color: Colors.grey[400]),
                            const SizedBox(width: 8),
                            Text(
                              'Inativos',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Divider(color: Colors.grey[300]),
                            ),
                          ],
                        ),
                      ),
                      ...inactiveMembers.map((member) => _MemberCard(
                            member: member,
                            inactive: true,
                            canManage: canManage,
                          )),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

class _MemberCard extends StatelessWidget {
  final CellMember member;
  final bool inactive;
  final bool canManage;
  final bool locked;
  const _MemberCard({required this.member, this.inactive = false, this.canManage = false, this.locked = false});

  String get _roleLabel {
    if (member.isLeader) return 'Líder';
    if (member.isHelper) return 'Auxiliar';
    if (member.isVisitor) return 'Visitante';
    return 'Membro';
  }

  Color _roleColor(ThemeData theme) {
    if (member.isLeader) return theme.colorScheme.primary;
    if (member.isHelper) return Colors.teal;
    if (member.isVisitor) return Colors.orange;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = inactive ? Colors.grey[400]! : _roleColor(theme);

    return Opacity(
      opacity: inactive ? 0.6 : 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: canManage && !locked
              ? () {
                  Navigator.pushNamed(
                    context,
                    '/edit-member',
                    arguments: member,
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      member.name[0].toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _roleLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                          if (inactive) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Inativo',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (locked)
                  Icon(Icons.lock_outline_rounded, size: 18, color: Colors.grey[300])
                else
                  Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
