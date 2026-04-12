import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cell_member_model.dart';
import '../../models/person_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cell_provider.dart';
import '../../services/firestore_service.dart';
import '../../config/theme.dart';

class EditCellScreen extends StatefulWidget {
  const EditCellScreen({super.key});

  @override
  State<EditCellScreen> createState() => _EditCellScreenState();
}

class _EditCellScreenState extends State<EditCellScreen> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  String? _selectedDay;
  int _hour = 19;
  int _minute = 30;
  bool _timeExpanded = false;
  bool _initialized = false;
  bool _saving = false;

  // Leader state
  String? _originalLeaderId;
  String? _selectedLeaderPersonId;
  String? _selectedLeaderName;

  // Search state
  List<CellMember> _allMembers = [];
  List<CellMember> _filteredMembers = [];
  Map<String, String> _cellNames = {};
  Map<String, String> _personIdRoles = {};
  Map<String, List<String>> _personCells = {};
  bool _loadingMembers = false;
  bool _isSearching = false;

  static const _weekDays = [
    ('Seg', 'Segunda'),
    ('Ter', 'Terça'),
    ('Qua', 'Quarta'),
    ('Qui', 'Quinta'),
    ('Sex', 'Sexta'),
    ('Sáb', 'Sábado'),
    ('Dom', 'Domingo'),
  ];

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final cell = context.read<CellProvider>().selectedCell;
      if (cell != null) {
        _nameController.text = cell.name.startsWith('Célula ')
            ? cell.name.substring(7)
            : cell.name;
        _selectedDay = cell.meetingDay;
        if (cell.meetingTime != null) {
          final parts = cell.meetingTime!.split(':');
          if (parts.length == 2) {
            _hour = int.tryParse(parts[0]) ?? 19;
            _minute = int.tryParse(parts[1]) ?? 30;
          }
        }
        _originalLeaderId = cell.leaderId;
        _selectedLeaderName = cell.leaderName;
      }
      _hourController = FixedExtentScrollController(initialItem: _hour);
      _minuteController = FixedExtentScrollController(initialItem: _minute ~/ 5);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final cell = context.read<CellProvider>().selectedCell;
    if (cell == null) return;

    setState(() => _loadingMembers = true);

    final firestoreService = FirestoreService();
    final db = FirebaseFirestore.instance;
    final churchId = context.read<AuthProvider>().churchId;

    // Load all people from the church (all congregations)
    Query<Map<String, dynamic>> peopleQuery = db.collection('people');
    if (churchId != null) {
      peopleQuery = peopleQuery.where('churchId', isEqualTo: churchId);
    }
    final peopleSnap = await peopleQuery.get();
    final people = peopleSnap.docs.map((d) => Person.fromFirestore(d)).toList();

    // Load cell_members to know which cells each person belongs to
    Query<Map<String, dynamic>> cmQuery = db.collection('cell_members')
        .where('isVisitor', isEqualTo: false);
    if (churchId != null) {
      cmQuery = cmQuery.where('churchId', isEqualTo: churchId);
    }
    final cellMembersSnap = await cmQuery.get();
    final cellMembers = cellMembersSnap.docs
        .map((d) => CellMember.fromFirestore(d))
        .toList();

    final cellIds = cellMembers.map((m) => m.cellId).toSet();
    final results = await Future.wait([
      firestoreService.getCellNames(cellIds),
      firestoreService.getUserRolesByPersonId(churchId: churchId),
    ]);
    final cellNames = results[0] as Map<String, String>;
    final nameRoles = results[1] as Map<String, String>;

    // Build personId → cell info mapping
    final personCells = <String, List<String>>{};
    final personToCellMember = <String, CellMember>{};
    for (final m in cellMembers) {
      if (m.personId.isEmpty) continue;
      final cellName = cellNames[m.cellId] ?? '';
      final label = m.isActive ? cellName : '$cellName (Inativo)';
      personCells.putIfAbsent(m.personId, () => []);
      if (label.isNotEmpty) personCells[m.personId]!.add(label);
      // Keep the first (or leader) cell_member for role display
      if (!personToCellMember.containsKey(m.personId) || m.isLeader) {
        personToCellMember[m.personId] = m;
      }
    }

    // Create CellMember-like entries for people not in any cell
    final allMembers = <CellMember>[];
    for (final person in people) {
      if (personToCellMember.containsKey(person.id)) {
        allMembers.add(personToCellMember[person.id]!);
      } else {
        // Person not in any cell — create a synthetic entry
        allMembers.add(CellMember(
          id: '',
          personId: person.id,
          personName: person.name,
          cellId: '',
          supervisionId: '',
          congregationId: person.congregationId,
          isActive: true,
          isLeader: false,
          isHelper: false,
          isVisitor: false,
          person: person,
        ));
      }
    }

    if (mounted) {
      setState(() {
        _allMembers = allMembers;
        _cellNames = cellNames;
        _personIdRoles = nameRoles;
        _personCells = personCells;
        _loadingMembers = false;
      });
      if (_searchController.text.trim().length >= 2) {
        _filterMembers(_searchController.text);
      }
    }
  }

  void _filterMembers(String query) {
    if (query.trim().length < 2) {
      setState(() => _filteredMembers = []);
      return;
    }
    final q = query.trim().toLowerCase();
    setState(() {
      final matched = _allMembers
          .where((m) =>
              m.name.toLowerCase().contains(q) && m.personId.isNotEmpty)
          .toList();

      int rolePriority(CellMember m) {
        if (m.isLeader) return 0;
        if (m.isHelper) return 1;
        return 2;
      }

      matched.sort((a, b) {
        final rp = rolePriority(a).compareTo(rolePriority(b));
        if (rp != 0) return rp;
        return a.name.compareTo(b.name);
      });

      final seen = <String>{};
      _filteredMembers = matched.where((m) {
        if (seen.contains(m.personId)) return false;
        seen.add(m.personId);
        return true;
      }).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    });
  }

  void _selectMember(CellMember member) {
    setState(() {
      _selectedLeaderPersonId = member.personId;
      _selectedLeaderName = member.name;
      _isSearching = false;
      _searchController.clear();
      _filteredMembers = [];
    });
  }

  String? _getRoleBadge(CellMember member) {
    final role = _personIdRoles[member.personId];
    if (role == 'pastor') return 'Pastor';
    if (role == 'supervisor') return 'Supervisor';
    if (member.isLeader) return 'Líder';
    if (member.isHelper) return 'Auxiliar';
    return null;
  }

  void _startSearch() {
    setState(() => _isSearching = true);
    if (_allMembers.isEmpty) _loadMembers();
  }

  void _clearSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _filteredMembers = [];
    });
  }

  void _confirmLeaderChange() {
    final firstName = _selectedLeaderName?.split(' ').first ?? '';
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
                color: AppColors.neutral300,
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
                Icons.swap_horiz_rounded,
                size: 28,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Alterar líder para $firstName?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'O líder atual será removido e $firstName assumirá a liderança desta célula.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.neutral500),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.neutral700,
                      side: const BorderSide(color: AppColors.neutral300),
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
                    onPressed: () {
                      Navigator.pop(ctx);
                      _save();
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Confirmar'),
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

  Future<void> _save() async {
    final suffix = _nameController.text.trim();
    if (suffix.isEmpty) return;

    final cellProvider = context.read<CellProvider>();
    final cell = cellProvider.selectedCell;
    if (cell == null) return;

    setState(() => _saving = true);

    try {
      final db = FirebaseFirestore.instance;
      final userId = context.read<AuthProvider>().appUser?.id ?? '';
      final fullName = 'Célula $suffix';
      final timeStr = '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

      final leaderChanged = _selectedLeaderPersonId != null;

      final cellUpdate = <String, dynamic>{
        'name': fullName,
        'meetingDay': _selectedDay,
        'meetingTime': timeStr,
      };

      if (leaderChanged) {
        // Resolve personId → userId via people collection
        final personDoc =
            await db.collection('people').doc(_selectedLeaderPersonId).get();
        final newLeaderUserId = personDoc.data()?['userId'] as String?;

        // Find the new leader's cell_member in this cell (if exists)
        final newLeaderCmSnap = await db
            .collection('cell_members')
            .where('personId', isEqualTo: _selectedLeaderPersonId)
            .where('cellId', isEqualTo: cell.id)
            .limit(1)
            .get();

        // Find ALL leaders in this cell (main + co-leader)
        final oldLeaderCmSnap = await db
            .collection('cell_members')
            .where('cellId', isEqualTo: cell.id)
            .where('isLeader', isEqualTo: true)
            .get();

        // 1. Demote all current leaders (except if one is the new leader)
        for (final oldCm in oldLeaderCmSnap.docs) {
          if (oldCm.data()['personId'] == _selectedLeaderPersonId) continue;
          await cellProvider.updateCellMember(oldCm.id, {
            'isLeader': false,
          });
          await FirestoreService().addMemberHistory(
            cellMemberId: oldCm.id,
            action: 'role_change',
            from: 'leader',
            to: 'member',
            changedBy: userId,
            cellId: cell.id,
          );
        }

        // 2. Promote new leader
        if (newLeaderCmSnap.docs.isNotEmpty) {
          // Already in cell — just promote
          final newCm = newLeaderCmSnap.docs.first;
          final fromRole = (newCm.data()['isHelper'] == true) ? 'helper' : 'member';
          await cellProvider.updateCellMember(newCm.id, {
            'isLeader': true,
            'isHelper': false,
          });
          await FirestoreService().addMemberHistory(
            cellMemberId: newCm.id,
            action: 'role_change',
            from: fromRole,
            to: 'leader',
            changedBy: userId,
            cellId: cell.id,
          );
        } else {
          // Not in cell — add as leader
          final newCmId = await cellProvider.addNewCellMember(CellMember(
            id: '',
            personId: _selectedLeaderPersonId!,
            personName: _selectedLeaderName!,
            cellId: cell.id,
            supervisionId: cell.supervisionId,
            congregationId: cell.congregationId,
            churchId: cell.churchId,
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
        cellUpdate['leaderName'] = _selectedLeaderName;
        if (newLeaderUserId != null) {
          cellUpdate['leaderId'] = newLeaderUserId;
        }

        // 4. Update user roles — only promote if current role is lower
        if (newLeaderUserId != null) {
          final newUserDoc = await db.collection('users').doc(newLeaderUserId).get();
          final currentRole = newUserDoc.data()?['role'] as String? ?? 'member';
          const higherRoles = {'admin', 'pastor', 'supervisor'};
          if (!higherRoles.contains(currentRole)) {
            await db.collection('users').doc(newLeaderUserId).update({
              'role': 'leader',
              'cellId': cell.id,
            });
          } else {
            // Keep role, just link cell
            await db.collection('users').doc(newLeaderUserId).update({
              'cellId': cell.id,
            });
          }
        }
        if (_originalLeaderId != null && _originalLeaderId != newLeaderUserId) {
          // Check if old leader has a higher role (pastor/admin/supervisor)
          final oldUserDoc = await db.collection('users').doc(_originalLeaderId).get();
          final oldRole = oldUserDoc.data()?['role'] as String? ?? 'member';
          const higherRoles = {'admin', 'pastor', 'supervisor'};

          if (!higherRoles.contains(oldRole)) {
            // Check if old leader leads other cells
            final otherCellsSnap = await db
                .collection('cells')
                .where('leaderId', isEqualTo: _originalLeaderId)
                .get();
            final otherCells = otherCellsSnap.docs
                .where((d) => d.id != cell.id)
                .toList();
            if (otherCells.isEmpty) {
              // Check if old leader is a supervisor
              final supSnap = await db
                  .collection('supervisions')
                  .where('supervisorId', isEqualTo: _originalLeaderId)
                  .limit(1)
                  .get();
              final isSupervisor = supSnap.docs.isNotEmpty;
              await db.collection('users').doc(_originalLeaderId).update({
                'role': isSupervisor ? 'supervisor' : 'member',
                'cellId': FieldValue.delete(),
              });
            }
          } else {
            // Higher role — just unlink cell
            await db.collection('users').doc(_originalLeaderId).update({
              'cellId': FieldValue.delete(),
            });
          }
        }
      }

      await cellProvider.updateCell(cell.id, cellUpdate);

      // Refresh user state so home screen reflects role changes
      if (leaderChanged && mounted) {
        await context.read<AuthProvider>().refreshUser();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Célula atualizada!')),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final user = context.read<AuthProvider>().appUser;
    final canChangeLeader = user != null && user.role != UserRole.leader;

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Célula')),
      body: Column(
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
                    color: AppColors.neutral600,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'Célula ',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: 'Nome da célula',
                              hintStyle: TextStyle(
                                color: AppColors.neutral400,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Líder ──
                Text(
                  'Líder',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral600,
                  ),
                ),
                const SizedBox(height: 8),

                if (!_isSearching && _selectedLeaderName != null) ...[
                  Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                primaryColor.withValues(alpha: 0.1),
                            child: Text(
                              _selectedLeaderName!.isNotEmpty
                                  ? _selectedLeaderName![0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedLeaderName!,
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Líder',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: AppColors.neutral500),
                                ),
                              ],
                            ),
                          ),
                          if (canChangeLeader)
                            IconButton(
                              icon: Icon(Icons.swap_horiz_rounded,
                                  color: AppColors.neutral400),
                              tooltip: 'Trocar líder',
                              onPressed: _startSearch,
                            ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        textCapitalization: TextCapitalization.words,
                        autofocus: _isSearching,
                        onChanged: _filterMembers,
                        decoration: InputDecoration(
                          hintText: 'Digite o nome do líder',
                          hintStyle: TextStyle(
                            color: AppColors.neutral400,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: AppColors.neutral400, size: 22),
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 36, minHeight: 0),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close,
                                      size: 18, color: AppColors.neutral400),
                                  onPressed: () {
                                    _searchController.clear();
                                    _filterMembers('');
                                  },
                                )
                              : (_isSearching && _selectedLeaderName != null)
                                  ? IconButton(
                                      icon: Icon(Icons.close,
                                          size: 18, color: AppColors.neutral400),
                                      onPressed: _clearSearch,
                                    )
                                  : null,
                        ),
                      ),
                    ),
                  ),

                  if (_searchController.text.trim().isEmpty) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.person_search_rounded,
                              size: 48, color: AppColors.neutral300),
                          const SizedBox(height: 8),
                          Text(
                            'Digite pelo menos 2 letras para buscar',
                            style: TextStyle(
                              color: AppColors.neutral500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_loadingMembers) ...[
                    const SizedBox(height: 24),
                    const Center(child: CircularProgressIndicator()),
                  ] else if (_searchController.text.trim().length >= 2 &&
                      _filteredMembers.isEmpty) ...[
                    const SizedBox(height: 24),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.person_search_rounded,
                              size: 48, color: AppColors.neutral300),
                          const SizedBox(height: 8),
                          Text(
                            'Nenhum membro encontrado',
                            style: TextStyle(
                              color: AppColors.neutral500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    ..._filteredMembers.take(20).map((member) {
                      final cells = _personCells[member.personId] ?? [];
                      final subtitle = cells.join(' · ');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Card(
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _selectMember(member),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                        primaryColor.withValues(alpha: 0.1),
                                    child: Text(
                                      member.name.isNotEmpty
                                          ? member.name[0].toUpperCase()
                                          : '?',
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          member.name,
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
                                              color: AppColors.neutral500,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (_getRoleBadge(member) != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color:
                                            primaryColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _getRoleBadge(member)!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_ios_rounded,
                                      color: AppColors.neutral400, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],

                const SizedBox(height: 20),

                // ── Dia da reunião ──
                Text(
                  'Dia da reunião',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _weekDays.map((day) {
                    final (abbr, full) = day;
                    final selected = _selectedDay == full;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedDay = selected ? null : full);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: selected
                              ? primaryColor
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? primaryColor
                                : AppColors.neutral300,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            abbr,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected ? AppColors.white : AppColors.neutral600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                // ── Horário ──
                Text(
                  'Horário',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.neutral600,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _timeExpanded = !_timeExpanded),
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
                                child: Icon(Icons.access_time_rounded,
                                    color: primaryColor, size: 22),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Horário da reunião',
                                      style: theme.textTheme.bodySmall
                                      ?.copyWith(color: AppColors.neutral500),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                _timeExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: AppColors.neutral400,
                              ),
                            ],
                          ),
                        ),
                      ),
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: SizedBox(
                          height: 150,
                          child: Row(
                            children: [
                              Expanded(
                                child: ListWheelScrollView.useDelegate(
                                  controller: _hourController,
                                  itemExtent: 40,
                                  physics: const FixedExtentScrollPhysics(),
                                  diameterRatio: 1.5,
                                  onSelectedItemChanged: (index) {
                                    setState(() => _hour = index);
                                  },
                                  childDelegate: ListWheelChildBuilderDelegate(
                                    childCount: 24,
                                    builder: (context, index) {
                                      final isSelected = index == _hour;
                                      return Center(
                                        child: Text(
                                          index.toString().padLeft(2, '0'),
                                          style: TextStyle(
                                            fontSize: isSelected ? 22 : 16,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                            color: isSelected
                                                ? primaryColor
                                                : AppColors.neutral400,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Text(
                                ':',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: primaryColor,
                                ),
                              ),
                              Expanded(
                                child: ListWheelScrollView.useDelegate(
                                  controller: _minuteController,
                                  itemExtent: 40,
                                  physics: const FixedExtentScrollPhysics(),
                                  diameterRatio: 1.5,
                                  onSelectedItemChanged: (index) {
                                    setState(() => _minute = index * 5);
                                  },
                                  childDelegate: ListWheelChildBuilderDelegate(
                                    childCount: 12,
                                    builder: (context, index) {
                                      final value = index * 5;
                                      final isSelected = value == _minute;
                                      return Center(
                                        child: Text(
                                          value.toString().padLeft(2, '0'),
                                          style: TextStyle(
                                            fontSize: isSelected ? 22 : 16,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                                            color: isSelected
                                                ? primaryColor
                                                : AppColors.neutral400,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        crossFadeState: _timeExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 200),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),

          // ── Botão Salvar (fixo no bottom) ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              border: Border(
                top: const BorderSide(color: AppColors.neutral200, width: 1),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : () {
                  final leaderChanged = _selectedLeaderPersonId != null;
                  if (leaderChanged) {
                    _confirmLeaderChange();
                  } else {
                    _save();
                  }
                },
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(
                  _saving ? 'Salvando...' : 'Salvar',
                  style: const TextStyle(
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
    );
  }
}
