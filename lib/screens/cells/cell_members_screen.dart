import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cell_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../utils/permissions.dart';
import '../../utils/role_colors.dart';
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

        final canManage = Permissions.canManageMembers(user, cell, cellMembers: cellProvider.cellMembers);

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
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                        elevation: 0,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () =>
                              Navigator.pushNamed(context, '/add-member'),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.person_add_rounded,
                                      color: Theme.of(context).colorScheme.primary, size: 24),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  'Adicionar Participante',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
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
                          locked: false,
                          mainLeaderId: cell.leaderId,
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
                            mainLeaderId: cell.leaderId,
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
  final String? mainLeaderId;
  const _MemberCard({required this.member, this.inactive = false, this.canManage = false, this.locked = false, this.mainLeaderId});

  String get _roleLabel => RoleColors.roleLabel(member, mainLeaderId: mainLeaderId);

  Color _roleColor(ThemeData theme) {
    return RoleColors.forMember(
      theme: theme,
      isLeader: member.isLeader,
      isHelper: member.isHelper,
      isVisitor: member.isVisitor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = inactive ? Colors.grey[400]! : _roleColor(theme);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: inactive ? 0.6 : 1.0,
        child: Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
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
      ),
    );
  }
}
