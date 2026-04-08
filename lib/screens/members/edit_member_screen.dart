import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/approval_request_model.dart';
import '../../models/cell_member_model.dart';
import '../../models/cell_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cell_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/permissions.dart';
import '../../utils/role_colors.dart';

class EditMemberScreen extends StatefulWidget {
  const EditMemberScreen({super.key});

  @override
  State<EditMemberScreen> createState() => _EditMemberScreenState();
}

class _EditMemberScreenState extends State<EditMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String _gender = 'M';
  DateTime? _birthDate;
  bool _birthDateExpanded = false;
  bool _initialized = false;
  bool _saving = false;
  late CellMember _member;
  bool _isSelfEdit = false;
  bool _isAdmin = false;
  bool _hasPendingRequest = false;
  bool _pendingCheckDone = false;

  bool get _canEditPersonalData =>
      _isAdmin || (_member.isVisitor && !_hasPendingRequest);

  bool get _canPromoteToLeader {
    final user = context.read<AuthProvider>().appUser;
    final cell = context.read<CellProvider>().selectedCell;
    if (user == null || cell == null) return false;
    return Permissions.canPromoteToLeader(user, cell);
  }

  bool get _canDemoteLeader {
    final user = context.read<AuthProvider>().appUser;
    final cell = context.read<CellProvider>().selectedCell;
    if (user == null || cell == null) return false;
    return Permissions.canPromoteToLeader(user, cell);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _member = ModalRoute.of(context)!.settings.arguments as CellMember;
      _nameController.text = _member.name;
      _gender = _member.gender ?? 'M';
      _birthDate = _member.birthDate;

      final user = context.read<AuthProvider>().appUser;
      final cell = context.read<CellProvider>().selectedCell;
      _isSelfEdit = _member.isLeader && cell?.leaderId == user?.id;
      _isAdmin = user?.role == UserRole.admin;

      _initialized = true;

      // For visitors (non-admin): check pending BEFORE allowing render
      // so the correct card shows immediately without flicker
      if (_member.isVisitor && !_isAdmin) {
        _pendingCheckDone = false;
        FirestoreService().hasPendingRequest(_member.id).then((hasPending) {
          if (mounted) {
            setState(() {
              _hasPendingRequest = hasPending;
              _pendingCheckDone = true;
            });
          }
        });
      } else {
        _pendingCheckDone = true;
      }

      _initAsync();
    }
  }

  Future<void> _initAsync() async {
    // Load person data if not populated
    if (_member.person == null && _member.personId.isNotEmpty) {
      final person = await FirestoreService().getPerson(_member.personId);
      if (mounted && person != null) {
        setState(() {
          _member.person = person;
          _gender = _member.gender ?? 'M';
          _birthDate = _member.birthDate;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _appBarTitle {
    if (_member.isLeader) return 'Editar Líder';
    if (_member.isHelper) return 'Editar Auxiliar';
    if (_member.isVisitor) return 'Editar Visitante';
    if (!_member.isActive) return 'Editar Inativo';
    return 'Editar Membro';
  }

  void _confirmPromoteToMember() async {
    final firstName = _nameController.text.trim().split(' ').first;

    // Admin promotes directly
    if (_isAdmin) {
      _showPromoteModal(firstName);
      return;
    }

    // Non-admin: check if already has pending request
    final hasPending =
        await FirestoreService().hasPendingRequest(_member.id);
    if (hasPending) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Já existe uma solicitação pendente para este visitante')),
        );
      }
      return;
    }

    if (!mounted) return;
    _showRequestApprovalModal(firstName);
  }

  void _showPromoteModal(String firstName) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.arrow_upward_rounded,
                size: 28,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Promover $firstName a membro?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Visitante será promovido(a) a membro da célula.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final cellProvider = context.read<CellProvider>();
                      final userId = context.read<AuthProvider>().appUser?.id ?? '';
                      await cellProvider.updateCellMember(_member.id, {
                        'isVisitor': false,
                      });
                      await FirestoreService().addMemberHistory(
                        cellMemberId: _member.id,
                        action: 'role_change',
                        from: 'visitor',
                        to: 'member',
                        changedBy: userId,
                        cellId: _member.cellId,
                      );
                      if (_member.personId.isNotEmpty) {
                        await cellProvider.updatePersonAndSync(
                            _member.personId, {'baptized': true});
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$firstName agora é membro!'),
                          ),
                        );
                        Navigator.pop(context);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Promover'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRequestApprovalModal(String firstName) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.send_rounded,
                size: 28,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Solicitar promoção de $firstName?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A solicitação será enviada ao administrador para aprovação.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final user = context.read<AuthProvider>().appUser;
                      final cell = context.read<CellProvider>().selectedCell;
                      if (user == null || cell == null) return;

                      final request = ApprovalRequest(
                        id: '',
                        type: 'promote_to_member',
                        personId: _member.personId,
                        personName: _member.name,
                        cellMemberId: _member.id,
                        cellId: cell.id,
                        cellName: cell.name,
                        requestedBy: user.id,
                        requestedByName: user.name,
                        status: ApprovalStatus.pending,
                        createdAt: DateTime.now(),
                      );

                      await FirestoreService().createApprovalRequest(request);
                      await FirestoreService().addMemberHistory(
                        cellMemberId: _member.id,
                        action: 'approval_created',
                        changedBy: user.id,
                        cellId: _member.cellId,
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Solicitação enviada! Aguardando aprovação do admin.'),
                          ),
                        );
                        Navigator.pop(context);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Enviar Solicitação'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmToggleActive() {
    final isActive = _member.isActive;
    final firstName = _nameController.text.trim().split(' ').first;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final message = isActive
        ? 'Tornar $firstName inativo(a)?'
        : 'Reativar $firstName?';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: (isActive ? RoleColors.inactive : Colors.green)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isActive ? Icons.person_off_outlined : Icons.person_add_alt_1,
                size: 28,
                color: isActive ? RoleColors.inactive : Colors.green[600],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 8),
              Text(
                'Membros inativos não aparecem na lista principal.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final cellProvider = context.read<CellProvider>();
                      final userId = context.read<AuthProvider>().appUser?.id ?? '';
                      // Cancel pending approval requests when inactivating a visitor
                      if (isActive && _member.isVisitor) {
                        await FirestoreService().cancelPendingRequests(_member.id, changedBy: userId);
                      }
                      final updates = <String, dynamic>{
                        'isActive': !isActive,
                      };
                      // Remove helper role on inactivation
                      if (isActive && _member.isHelper) {
                        updates['isHelper'] = false;
                      }
                      await cellProvider.updateCellMember(_member.id, updates);
                      await FirestoreService().addMemberHistory(
                        cellMemberId: _member.id,
                        action: 'status_change',
                        from: isActive ? 'active' : 'inactive',
                        to: isActive ? 'inactive' : 'active',
                        changedBy: userId,
                        cellId: _member.cellId,
                      );
                      // Track helper demotion if inactivating a helper
                      if (isActive && _member.isHelper) {
                        await FirestoreService().addMemberHistory(
                          cellMemberId: _member.id,
                          action: 'role_change',
                          from: 'helper',
                          to: 'member',
                          changedBy: userId,
                          cellId: _member.cellId,
                        );
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isActive
                                ? '$firstName foi inativado(a)'
                                : '$firstName foi reativado(a)'),
                          ),
                        );
                        Navigator.pop(context);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          isActive ? RoleColors.inactive : Colors.green[600],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(isActive ? 'Inativar' : 'Reativar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    final firstName = _nameController.text.trim().split(' ').first;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.delete_outline,
                size: 28,
                color: Colors.red[700],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Excluir $firstName permanentemente?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Essa ação não pode ser desfeita.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final cellProvider = context.read<CellProvider>();
                      final userId = context.read<AuthProvider>().appUser?.id ?? '';
                      // Cancel pending approval requests when deleting a visitor
                      if (_member.isVisitor) {
                        await FirestoreService().cancelPendingRequests(_member.id, changedBy: userId);
                      }
                      await FirestoreService().addMemberHistory(
                        cellMemberId: _member.id,
                        action: 'removed',
                        changedBy: userId,
                        cellId: _member.cellId,
                      );
                      await cellProvider.deleteCellMember(_member.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$firstName foi excluído(a)'),
                          ),
                        );
                        Navigator.pop(context);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Excluir'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmToggleHelper() {
    final firstName = _nameController.text.trim().split(' ').first;
    final willBeHelper = !_member.isHelper;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final message = willBeHelper
        ? 'Tornar $firstName auxiliar da célula?'
        : 'Remover $firstName como auxiliar?';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: primaryColor
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                willBeHelper ? Icons.volunteer_activism : Icons.person_rounded,
                size: 28,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (willBeHelper) ...[
              const SizedBox(height: 8),
              Text(
                'Auxiliares ajudam o líder na condução da célula.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final cellProvider = context.read<CellProvider>();
                      final userId = context.read<AuthProvider>().appUser?.id ?? '';
                      await cellProvider.updateCellMember(_member.id, {
                        'isHelper': willBeHelper,
                      });
                      await FirestoreService().addMemberHistory(
                        cellMemberId: _member.id,
                        action: 'role_change',
                        from: willBeHelper ? 'member' : 'helper',
                        to: willBeHelper ? 'helper' : 'member',
                        changedBy: userId,
                        cellId: _member.cellId,
                      );
                      if (willBeHelper && _member.personId.isNotEmpty) {
                        await cellProvider.updatePersonAndSync(
                            _member.personId, {'baptized': true});
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(willBeHelper
                                ? '$firstName agora é auxiliar!'
                                : '$firstName não é mais auxiliar'),
                          ),
                        );
                        Navigator.pop(context);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(willBeHelper ? 'Confirmar' : 'Remover'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmPromoteToLeader() {
    final cellProvider = context.read<CellProvider>();
    final leaderCount = cellProvider.cellMembers.where((m) => m.isLeader).length;

    if (leaderCount >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta célula já possui 2 líderes (máximo permitido).'),
        ),
      );
      return;
    }

    final firstName = _nameController.text.trim().split(' ').first;
    final primaryColor = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.star_rounded,
                size: 28,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Promover $firstName a líder?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Esta pessoa passará a liderar esta célula.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final cellProvider = context.read<CellProvider>();
                      final userId = context.read<AuthProvider>().appUser?.id ?? '';
                      final fromRole = _member.isHelper ? 'helper' : 'member';
                      await cellProvider.updateCellMember(_member.id, {
                        'isLeader': true,
                        'isHelper': false,
                      });
                      await FirestoreService().addMemberHistory(
                        cellMemberId: _member.id,
                        action: 'role_change',
                        from: fromRole,
                        to: 'leader',
                        changedBy: userId,
                        cellId: _member.cellId,
                      );
                      if (_member.personId.isNotEmpty) {
                        await cellProvider.updatePersonAndSync(
                            _member.personId, {'baptized': true});
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$firstName agora é líder!'),
                          ),
                        );
                        Navigator.pop(context);
                      }
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Promover'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDemoteLeader() {
    final firstName = _nameController.text.trim().split(' ').first;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.person_remove_rounded,
                size: 28,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Remover $firstName como líder?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Escolha o que fazer com $firstName.\nDepois, selecione o novo líder.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _selectNewLeader(inactivate: false);
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Rebaixar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _selectNewLeader(inactivate: true);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red[400],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Inativar'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[300]!),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _selectNewLeader({required bool inactivate}) async {
    final cell = context.read<CellProvider>().selectedCell;
    final user = context.read<AuthProvider>().appUser;
    if (cell == null || user == null) return;

    // Show loading modal immediately
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final service = FirestoreService();
    final allMembers = await service.getCellMembersByCongregation(cell.congregationId);

    // Load supplementary data (cell names + user roles)
    final cellIds = allMembers.map((m) => m.cellId).toSet();
    final results = await Future.wait([
      service.getCellNames(cellIds),
      service.getUserRolesByName(),
    ]);
    final cellNameMap = results[0] as Map<String, String>;
    final nameRoles = results[1] as Map<String, String>;

    // Build personCells map (personId → list of cell names)
    final personCells = <String, List<String>>{};
    for (final m in allMembers) {
      if (m.personId.isEmpty) continue;
      final cellName = cellNameMap[m.cellId] ?? '';
      personCells.putIfAbsent(m.personId, () => []);
      if (cellName.isNotEmpty) personCells[m.personId]!.add(cellName);
    }

    // Filter: exclude the leader being demoted
    final candidates = allMembers
        .where((m) => m.id != _member.id && m.personId != _member.personId)
        .toList();

    // Sort by role priority (leader > helper > member) then name
    int rolePriority(CellMember m) {
      if (m.isLeader) return 0;
      if (m.isHelper) return 1;
      return 2;
    }
    candidates.sort((a, b) {
      final rp = rolePriority(a).compareTo(rolePriority(b));
      if (rp != 0) return rp;
      return a.name.compareTo(b.name);
    });

    // Dedup by personId (keeps highest role)
    final seen = <String>{};
    final deduped = candidates.where((m) {
      if (m.personId.isEmpty) return true;
      if (seen.contains(m.personId)) return false;
      seen.add(m.personId);
      return true;
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final sameCellMembers = deduped.where((m) => m.cellId == cell.id).toList();
    final otherCellMembers = deduped.where((m) => m.cellId != cell.id).toList();

    // Find user's cell_member record (if any) to reuse in demotion
    final userCellMember = deduped.where((m) =>
        m.name.toLowerCase() == user.name.toLowerCase()).firstOrNull;

    // Remove user from regular lists (they'll appear as "Eu mesmo" instead)
    if (userCellMember != null) {
      sameCellMembers.removeWhere((m) => m.id == userCellMember.id);
      otherCellMembers.removeWhere((m) => m.id == userCellMember.id);
    }

    if (!mounted) return;
    Navigator.pop(context); // dismiss loading spinner

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _NewLeaderSelector(
        sameCellMembers: sameCellMembers,
        otherCellMembers: otherCellMembers,
        cellNameMap: cellNameMap,
        nameRoles: nameRoles,
        personCells: personCells,
        currentCell: cell,
        showSelfOption: true,
        selfName: user.name,
        selfRole: user.roleDisplayName,
        onSelected: (newLeader) {
          Navigator.pop(ctx);
          _executeDemotion(newLeader: newLeader, inactivate: inactivate);
        },
        onSelfSelected: () {
          Navigator.pop(ctx);
          if (userCellMember != null) {
            _executeDemotion(newLeader: userCellMember, inactivate: inactivate);
          } else {
            _executeDemotionWithSelf(inactivate: inactivate);
          }
        },
      ),
    );
  }

  Future<void> _executeDemotion({
    required CellMember newLeader,
    required bool inactivate,
  }) async {
    final cellProvider = context.read<CellProvider>();
    final cell = cellProvider.selectedCell;
    if (cell == null) return;

    setState(() => _saving = true);

    try {
      final userId = context.read<AuthProvider>().appUser?.id ?? '';
      // 1. Demote current leader
      await cellProvider.updateCellMember(_member.id, {
        'isLeader': false,
        if (inactivate) 'isActive': false,
      });
      await FirestoreService().addMemberHistory(
        cellMemberId: _member.id,
        action: 'role_change',
        from: 'leader',
        to: 'member',
        changedBy: userId,
        cellId: _member.cellId,
      );
      if (inactivate) {
        await FirestoreService().addMemberHistory(
          cellMemberId: _member.id,
          action: 'status_change',
          from: 'active',
          to: 'inactive',
          changedBy: userId,
          cellId: _member.cellId,
        );
      }

      // 2. Promote new leader
      if (newLeader.cellId == cell.id) {
        final fromRole = newLeader.isHelper ? 'helper' : 'member';
        await cellProvider.updateCellMember(newLeader.id, {
          'isLeader': true,
          'isHelper': false,
        });
        await FirestoreService().addMemberHistory(
          cellMemberId: newLeader.id,
          action: 'role_change',
          from: fromRole,
          to: 'leader',
          changedBy: userId,
          cellId: cell.id,
        );
      } else {
        final newCmId = await cellProvider.addNewCellMember(CellMember(
          id: '',
          personId: newLeader.personId,
          personName: newLeader.name,
          cellId: cell.id,
          supervisionId: cell.supervisionId,
          congregationId: cell.congregationId,
          isLeader: true,
        ));
        if (newCmId != null) {
          await FirestoreService().addMemberHistory(
            cellMemberId: newCmId,
            action: 'joined',
            changedBy: userId,
            cellId: cell.id,
          );
          await FirestoreService().addMemberHistory(
            cellMemberId: newCmId,
            action: 'role_change',
            from: 'member',
            to: 'leader',
            changedBy: userId,
            cellId: cell.id,
          );
        }
      }

      // 3. Update cell doc
      await cellProvider.updateCell(cell.id, {
        'leaderName': newLeader.name,
      });

      if (mounted) {
        final firstName = _nameController.text.trim().split(' ').first;
        final action = inactivate ? 'inativado' : 'rebaixado a membro';
        final newFirst = newLeader.name.split(' ').first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$firstName foi $action. $newFirst é o novo líder!'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _executeDemotionWithSelf({required bool inactivate}) async {
    final cellProvider = context.read<CellProvider>();
    final cell = cellProvider.selectedCell;
    final user = context.read<AuthProvider>().appUser;
    if (cell == null || user == null) return;

    setState(() => _saving = true);

    try {
      // 1. Demote current leader
      await cellProvider.updateCellMember(_member.id, {
        'isLeader': false,
        if (inactivate) 'isActive': false,
      });
      await FirestoreService().addMemberHistory(
        cellMemberId: _member.id,
        action: 'role_change',
        from: 'leader',
        to: 'member',
        changedBy: user.id,
        cellId: _member.cellId,
      );
      if (inactivate) {
        await FirestoreService().addMemberHistory(
          cellMemberId: _member.id,
          action: 'status_change',
          from: 'active',
          to: 'inactive',
          changedBy: user.id,
          cellId: _member.cellId,
        );
      }

      // 2. Resolve personId (create person record if needed)
      var personId = user.personId ?? '';
      if (personId.isEmpty) {
        final db = FirebaseFirestore.instance;
        // Try to find existing person by userId
        final existingPerson = await db
            .collection('people')
            .where('userId', isEqualTo: user.id)
            .limit(1)
            .get();
        if (existingPerson.docs.isNotEmpty) {
          personId = existingPerson.docs.first.id;
        } else {
          // Create a person record for this user
          final newPersonRef = await db.collection('people').add({
            'name': user.name,
            'userId': user.id,
            'congregationId': cell.congregationId,
            'createdAt': FieldValue.serverTimestamp(),
          });
          personId = newPersonRef.id;
        }
      }

      // 3. Create cell_member doc for self as leader
      await cellProvider.addNewCellMember(CellMember(
        id: '',
        personId: personId,
        personName: user.name,
        cellId: cell.id,
        supervisionId: cell.supervisionId,
        congregationId: cell.congregationId,
        isLeader: true,
      ));

      // 3. Update cell doc
      await cellProvider.updateCell(cell.id, {
        'leaderName': user.name,
        'leaderId': user.id,
      });

      if (mounted) {
        final firstName = _nameController.text.trim().split(' ').first;
        final action = inactivate ? 'inativado' : 'rebaixado a membro';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$firstName foi $action. Você é o novo líder!'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final cellProvider = context.read<CellProvider>();
      final authProvider = _isSelfEdit ? context.read<AuthProvider>() : null;

      // Personal data → person collection
      if (_member.personId.isNotEmpty) {
        await cellProvider.updatePersonAndSync(_member.personId, {
          'name': _nameController.text.trim(),
          'gender': _gender,
          'birthDate': _birthDate,
        });
      } else {
        // Fallback: update cell_member directly (for members without personId)
        await cellProvider.updateCellMember(_member.id, {
          'personName': _nameController.text.trim(),
        });
      }

      if (authProvider != null) {
        await authProvider.refreshUser();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Membro atualizado!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: Text(_appBarTitle)),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  // ── Nome ──
                  Text(
                    'Nome',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        readOnly: !_canEditPersonalData,
                        decoration: InputDecoration(
                          hintText: 'Nome completo',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                          suffixIcon: !_canEditPersonalData
                              ? Icon(Icons.lock_outline,
                                  size: 18, color: Colors.grey[400])
                              : null,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Informe o nome';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Sexo ──
                  Text(
                    'Sexo',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  IgnorePointer(
                    ignoring: !_canEditPersonalData,
                    child: Opacity(
                      opacity: !_canEditPersonalData ? 0.6 : 1.0,
                      child: Row(
                        children: [
                          Expanded(
                            child: _TypeOption(
                              label: 'Masculino',
                              icon: Icons.male_rounded,
                              selected: _gender == 'M',
                              color: primaryColor,
                              onTap: () => setState(() => _gender = 'M'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _TypeOption(
                              label: 'Feminino',
                              icon: Icons.female_rounded,
                              selected: _gender == 'F',
                              color: primaryColor,
                              onTap: () => setState(() => _gender = 'F'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Data de Nascimento ──
                  Text(
                    'Data de Nascimento',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  IgnorePointer(
                    ignoring: !_canEditPersonalData,
                    child: Opacity(
                      opacity: !_canEditPersonalData ? 0.6 : 1.0,
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                      children: [
                        InkWell(
                          onTap: () => setState(
                              () => _birthDateExpanded = !_birthDateExpanded),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: (_birthDate != null
                                            ? primaryColor
                                            : Colors.grey)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.cake_rounded,
                                    color: _birthDate != null
                                        ? primaryColor
                                        : Colors.grey[400],
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Opcional',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                                color: Colors.grey[500]),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _birthDate != null
                                            ? '${_birthDate!.day.toString().padLeft(2, '0')}/${_birthDate!.month.toString().padLeft(2, '0')}/${_birthDate!.year}'
                                            : 'Selecionar data',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: _birthDate != null
                                              ? primaryColor
                                              : Colors.grey[400],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_birthDate != null)
                                  IconButton(
                                    icon: Icon(Icons.close,
                                        size: 20, color: Colors.grey[400]),
                                    onPressed: () => setState(() {
                                      _birthDate = null;
                                      _birthDateExpanded = false;
                                    }),
                                  )
                                else
                                  Icon(
                                    _birthDateExpanded
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: Colors.grey[400],
                                  ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: CalendarDatePicker(
                            initialDate: _birthDate ?? DateTime(2000, 1, 1),
                            firstDate: DateTime(1920),
                            lastDate: DateTime.now(),
                            onDateChanged: (date) {
                              setState(() {
                                _birthDate = date;
                                _birthDateExpanded = false;
                              });
                            },
                          ),
                          crossFadeState: _birthDateExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 200),
                        ),
                      ],
                    ),
                  ),
                  ),
                  ),

                  // ── Promover visitante a membro ──
                  if (_member.isVisitor) ...[
                    const SizedBox(height: 20),
                    if (!_pendingCheckDone) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ] else if (_hasPendingRequest && !_isAdmin) ...[
                      Card(
                        color: primaryColor.withValues(alpha: 0.08),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.hourglass_top_rounded,
                                  color: primaryColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Aguardando Aprovação',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Solicitação enviada ao administrador',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Card(
                        color: primaryColor.withValues(alpha: 0.08),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _confirmPromoteToMember,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: primaryColor
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.arrow_upward_rounded,
                                    color: primaryColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    'Promover a Membro',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: primaryColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],

                  // ── Tornar/Remover Auxiliar ──
                  if (!_member.isLeader &&
                      !_member.isVisitor &&
                      _member.isActive) ...[
                    const SizedBox(height: 16),
                    Card(
                      color: primaryColor.withValues(alpha: 0.08),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _confirmToggleHelper,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  _member.isHelper
                                      ? Icons.person_rounded
                                      : Icons.volunteer_activism,
                                  color: primaryColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  _member.isHelper
                                      ? 'Remover como Auxiliar'
                                      : 'Tornar Auxiliar',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: primaryColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

                  // ── Promover a Líder ──
                  if (!_member.isLeader &&
                      !_member.isVisitor &&
                      _member.isActive &&
                      _canPromoteToLeader) ...[
                    const SizedBox(height: 8),
                    Card(
                      color: primaryColor.withValues(alpha: 0.04),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _confirmPromoteToLeader,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.star_rounded,
                                  color: primaryColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  'Promover a Líder',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: primaryColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

                  // ── Inativar/Reativar ──
                  if (!_member.isLeader && !_hasPendingRequest) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton.icon(
                        onPressed: _confirmToggleActive,
                        icon: Icon(
                          _member.isActive
                              ? Icons.person_off_outlined
                              : Icons.person_add_alt_1,
                        ),
                        label: Text(
                          _member.isActive
                              ? 'Tornar Inativo'
                              : 'Reativar Membro',
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: _member.isActive
                              ? RoleColors.inactive
                              : Colors.green[600],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // ── Excluir permanentemente ──
                  if (!_member.isActive) ...[
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton.icon(
                        onPressed: _confirmDelete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Excluir permanentemente'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Botão Salvar (fixo no bottom, só admin) ──
            if (_canEditPersonalData)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text(
                    'Salvar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? color : const Color(0xFFE0E0E0),
          width: selected ? 2 : 1,
        ),
      ),
      color: selected ? color.withValues(alpha: 0.05) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: selected ? color : Colors.grey[400], size: 28),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : Colors.grey[400],
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewLeaderSelector extends StatefulWidget {
  final List<CellMember> sameCellMembers;
  final List<CellMember> otherCellMembers;
  final Map<String, String> cellNameMap;
  final Map<String, String> nameRoles;
  final Map<String, List<String>> personCells;
  final CellGroup currentCell;
  final bool showSelfOption;
  final String selfName;
  final String selfRole;
  final void Function(CellMember) onSelected;
  final VoidCallback onSelfSelected;

  const _NewLeaderSelector({
    required this.sameCellMembers,
    required this.otherCellMembers,
    required this.cellNameMap,
    required this.nameRoles,
    required this.personCells,
    required this.currentCell,
    required this.showSelfOption,
    required this.selfName,
    required this.selfRole,
    required this.onSelected,
    required this.onSelfSelected,
  });

  @override
  State<_NewLeaderSelector> createState() => _NewLeaderSelectorState();
}

class _NewLeaderSelectorState extends State<_NewLeaderSelector> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String? _getRoleBadge(CellMember member) {
    final role = widget.nameRoles[member.name.toLowerCase()];
    if (role == 'pastor') return 'Pastor';
    if (role == 'supervisor') return 'Supervisor';
    if (member.isLeader) return 'Líder';
    if (member.isHelper) return 'Auxiliar';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    final sameFiltered = widget.sameCellMembers
        .where((m) => m.name.toLowerCase().contains(_searchQuery))
        .toList();
    final otherFiltered = widget.otherCellMembers
        .where((m) => m.name.toLowerCase().contains(_searchQuery))
        .toList();
    final showSelf = widget.showSelfOption &&
        (_searchQuery.isEmpty ||
            widget.selfName.toLowerCase().contains(_searchQuery));

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.star_rounded,
                        color: primaryColor, size: 28),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Selecionar novo líder',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Quem será o novo líder desta célula?',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 16),
                  // Search
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar membro...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      isDense: true,
                    ),
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.toLowerCase()),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            // List
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Self option
                  if (showSelf) ...[
                    _sectionHeader('Eu mesmo'),
                    _candidateTile(
                      name: widget.selfName,
                      subtitle: '',
                      roleBadge: widget.selfRole,
                      primaryColor: primaryColor,
                      onTap: widget.onSelfSelected,
                    ),
                  ],
                  // Same cell
                  if (sameFiltered.isNotEmpty) ...[
                    _sectionHeader('Membros desta célula'),
                    ...sameFiltered.map((m) {
                      final cells = widget.personCells[m.personId] ?? [];
                      final subtitle = cells.join(' · ');
                      return _candidateTile(
                        name: m.name,
                        subtitle: subtitle,
                        roleBadge: _getRoleBadge(m),
                        primaryColor: primaryColor,
                        onTap: () => widget.onSelected(m),
                      );
                    }),
                  ],
                  // Other cells
                  if (otherFiltered.isNotEmpty) ...[
                    _sectionHeader('Outros membros'),
                    ...otherFiltered.map((m) {
                      final cells = widget.personCells[m.personId] ?? [];
                      final subtitle = cells.join(' · ');
                      return _candidateTile(
                        name: m.name,
                        subtitle: subtitle,
                        roleBadge: _getRoleBadge(m),
                        primaryColor: primaryColor,
                        onTap: () => widget.onSelected(m),
                      );
                    }),
                  ],
                  if (!showSelf &&
                      sameFiltered.isEmpty &&
                      otherFiltered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Text(
                              'Nenhum membro encontrado',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey[500],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _candidateTile({
    required String name,
    required String subtitle,
    required String? roleBadge,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ),
                if (roleBadge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      roleBadge,
                      style: TextStyle(
                        fontSize: 11,
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
