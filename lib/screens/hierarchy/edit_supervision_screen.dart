import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cell_member_model.dart';
import '../../models/person_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/hierarchy_provider.dart';
import '../../services/firestore_service.dart';

class EditSupervisionScreen extends StatefulWidget {
  const EditSupervisionScreen({super.key});

  @override
  State<EditSupervisionScreen> createState() => _EditSupervisionScreenState();
}

class _EditSupervisionScreenState extends State<EditSupervisionScreen> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  bool _initialized = false;
  bool _saving = false;

  String? _originalSupervisorId;
  String? _selectedSupervisorId;
  String? _selectedSupervisorName;

  // Search state
  List<CellMember> _allMembers = [];
  List<CellMember> _filteredMembers = [];
  Map<String, String> _cellNames = {};
  Map<String, String> _personIdRoles = {};
  Map<String, List<String>> _personCells = {};
  bool _loadingMembers = false;
  bool _isSearching = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final supervision =
          context.read<HierarchyProvider>().selectedSupervision;
      if (supervision != null) {
        _nameController.text = supervision.name.startsWith('Supervisão ')
            ? supervision.name.substring(11)
            : supervision.name;
        _originalSupervisorId = supervision.supervisorId;
        _selectedSupervisorId = supervision.supervisorId;
        _selectedSupervisorName = supervision.supervisorName;
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    final supervision =
        context.read<HierarchyProvider>().selectedSupervision;
    if (supervision == null) return;

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

    final personCells = <String, List<String>>{};
    final personToCellMember = <String, CellMember>{};
    for (final m in cellMembers) {
      if (m.personId.isEmpty) continue;
      final cellName = cellNames[m.cellId] ?? '';
      final label = m.isActive ? cellName : '$cellName (Inativo)';
      personCells.putIfAbsent(m.personId, () => []);
      if (label.isNotEmpty) personCells[m.personId]!.add(label);
      if (!personToCellMember.containsKey(m.personId) || m.isLeader) {
        personToCellMember[m.personId] = m;
      }
    }

    final allMembers = <CellMember>[];
    for (final person in people) {
      if (personToCellMember.containsKey(person.id)) {
        allMembers.add(personToCellMember[person.id]!);
      } else {
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
      _selectedSupervisorId = member.personId;
      _selectedSupervisorName = member.name;
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

  void _confirmSupervisorChange() {
    final firstName = _selectedSupervisorName?.split(' ').first ?? '';
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
                Icons.swap_horiz_rounded,
                size: 28,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Alterar supervisor para $firstName?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'O supervisor atual será removido e $firstName assumirá esta supervisão.',
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

    final hierarchy = context.read<HierarchyProvider>();
    final supervision = hierarchy.selectedSupervision;
    if (supervision == null) return;

    setState(() => _saving = true);

    try {
      final db = FirebaseFirestore.instance;
      final fullName = 'Supervisão $suffix';
      final updateData = <String, dynamic>{'name': fullName};

      if (_selectedSupervisorId != null) {
        // Resolve selected personId → userId
        final personDoc =
            await db.collection('people').doc(_selectedSupervisorId).get();
        final newUserId = personDoc.data()?['userId'] as String?;

        // Compare resolved userId with the current supervisorId on the supervision doc
        final supervisorChanged = newUserId != _originalSupervisorId;

        if (supervisorChanged && newUserId != null) {
          updateData['supervisorId'] = newUserId;
          updateData['supervisorName'] = _selectedSupervisorName;

          await hierarchy.updateSupervision(supervision.id, updateData);

          // Promote new supervisor if current role is lower
          final newUserDoc = await db.collection('users').doc(newUserId).get();
          final currentRole = newUserDoc.data()?['role'] as String? ?? 'leader';
          const higherRoles = {'admin', 'pastor'};
          if (!higherRoles.contains(currentRole)) {
            await db.collection('users').doc(newUserId).update({
              'role': 'supervisor',
            });
          }

          // Handle old supervisor (skip if same person)
          if (_originalSupervisorId != null && _originalSupervisorId != newUserId) {
            // Check if old supervisor still has OTHER supervisions
            final otherSups = await db
                .collection('supervisions')
                .where('supervisorId', isEqualTo: _originalSupervisorId)
                .get();
            final hasOtherSupervisions = otherSups.docs.isNotEmpty;

            if (!hasOtherSupervisions) {
              final oldUserDoc = await db.collection('users').doc(_originalSupervisorId).get();
              final oldRole = oldUserDoc.data()?['role'] as String? ?? 'leader';

              if (!higherRoles.contains(oldRole)) {
                // Check if they lead a cell
                final cellsSnap = await db
                    .collection('cells')
                    .where('leaderId', isEqualTo: _originalSupervisorId)
                    .limit(1)
                    .get();

                await db.collection('users').doc(_originalSupervisorId).update({
                  'role': cellsSnap.docs.isNotEmpty ? 'leader' : 'member',
                });
              }
            }
            // If has other supervisions, keep role as-is
          }
        } else if (supervisorChanged && newUserId == null) {
          // Person has no user account — just update supervision reference
          updateData['supervisorId'] = _selectedSupervisorId;
          updateData['supervisorName'] = _selectedSupervisorName;
          await hierarchy.updateSupervision(supervision.id, updateData);
        } else {
          // Same supervisor, just update name
          await hierarchy.updateSupervision(supervision.id, updateData);
        }
      } else {
        await hierarchy.updateSupervision(supervision.id, updateData);
      }

      // Refresh user state so home screen reflects role changes
      if (mounted) {
        await context.read<AuthProvider>().refreshUser();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supervisão atualizada!')),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Editar Supervisão')),
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
                    color: Colors.grey[600],
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
                          'Supervisão ',
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
                              hintText: 'Nome da supervisão',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
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

                // ── Supervisor ──
                Text(
                  'Supervisor',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),

                if (!_isSearching && _selectedSupervisorName != null) ...[
                  // ── Selected supervisor card ──
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
                              _selectedSupervisorName!.isNotEmpty
                                  ? _selectedSupervisorName![0].toUpperCase()
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
                                  _selectedSupervisorName!,
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Supervisor',
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.swap_horiz_rounded,
                                color: Colors.grey[400]),
                            tooltip: 'Trocar supervisor',
                            onPressed: _startSearch,
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // ── Search field ──
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
                          hintText: 'Digite o nome do supervisor',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[400],
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: Colors.grey[400], size: 22),
                          prefixIconConstraints:
                              const BoxConstraints(minWidth: 36, minHeight: 0),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close,
                                      size: 18, color: Colors.grey[400]),
                                  onPressed: () {
                                    _searchController.clear();
                                    _filterMembers('');
                                  },
                                )
                              : (_isSearching &&
                                      _selectedSupervisorName != null)
                                  ? IconButton(
                                      icon: Icon(Icons.close,
                                          size: 18, color: Colors.grey[400]),
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
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          Text(
                            'Digite pelo menos 2 letras para buscar',
                            style: TextStyle(
                              color: Colors.grey[500],
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
                              size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          Text(
                            'Nenhum membro encontrado',
                            style: TextStyle(
                              color: Colors.grey[500],
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
                                              color: Colors.grey[500],
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
                                      color: Colors.grey[400], size: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ],
            ),
          ),

          // ── Botão Salvar fixo no bottom ──
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
                onPressed: _saving ? null : () {
                  final supervisorChanged =
                      _selectedSupervisorId != _originalSupervisorId &&
                          _selectedSupervisorId != null;
                  if (supervisorChanged) {
                    _confirmSupervisorChange();
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
                          color: Colors.white,
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
