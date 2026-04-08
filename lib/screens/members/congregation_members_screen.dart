import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/hierarchy_provider.dart';
import '../../providers/cell_provider.dart';
import '../../models/cell_member_model.dart';
import '../../models/cell_model.dart';
import '../../utils/role_colors.dart';

class CongregationMembersScreen extends StatefulWidget {
  const CongregationMembersScreen({super.key});

  @override
  State<CongregationMembersScreen> createState() =>
      _CongregationMembersScreenState();
}

class _CongregationMembersScreenState
    extends State<CongregationMembersScreen> {
  final _db = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  List<CellMember> _members = [];
  Map<String, String> _cellNames = {};
  Map<String, String> _supNames = {};
  Map<String, String> _cellToSup = {};
  bool _loading = true;
  String _searchQuery = '';
  String _filterSup = 'Todas';
  List<String> _supFilterOptions = ['Todas'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final hierarchy = context.read<HierarchyProvider>();
    final congregation = hierarchy.selectedCongregation;
    if (congregation == null) return;

    final supsSnap = await _db
        .collection('supervisions')
        .where('congregationId', isEqualTo: congregation.id)
        .get();
    final supNames = <String, String>{};
    for (final doc in supsSnap.docs) {
      supNames[doc.id] = (doc.data())['name'] ?? 'Supervisão';
    }

    final cellsSnap = await _db
        .collection('cells')
        .where('congregationId', isEqualTo: congregation.id)
        .get();
    final cells =
        cellsSnap.docs.map((d) => CellGroup.fromFirestore(d)).toList();
    final cellNames = {for (var c in cells) c.id: c.name};
    final cellToSup = {for (var c in cells) c.id: c.supervisionId};

    final membersSnap = await _db
        .collection('cell_members')
        .where('congregationId', isEqualTo: congregation.id)
        .get();
    final members = membersSnap.docs
        .map((d) => CellMember.fromFirestore(d))
        .where((m) => m.isActive)
        .toList()
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

    if (mounted) {
      setState(() {
        _members = members;
        _cellNames = cellNames;
        _supNames = supNames;
        _cellToSup = cellToSup;
        _supFilterOptions = ['Todas', ...supNames.values.toList()..sort()];
        _loading = false;
      });
    }
  }

  List<CellMember> get _filteredMembers {
    var list = _members;
    if (_searchQuery.isNotEmpty) {
      list = list
          .where((m) => m.name.toLowerCase().contains(_searchQuery))
          .toList();
    }
    if (_filterSup != 'Todas') {
      final supId = _supNames.entries
          .where((e) => e.value == _filterSup)
          .map((e) => e.key)
          .firstOrNull;
      if (supId != null) {
        final cellIdsInSup = _cellToSup.entries
            .where((e) => e.value == supId)
            .map((e) => e.key)
            .toSet();
        list = list.where((m) => cellIdsInSup.contains(m.cellId)).toList();
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final hierarchy = context.watch<HierarchyProvider>();
    final congregation = hierarchy.selectedCongregation;

    return Scaffold(
      appBar: AppBar(
        title: Text(congregation?.name ?? 'Participantes'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar membro...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
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
                ),
                // Supervision filter chips
                if (_supFilterOptions.length > 2)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Row(
                      children: _supFilterOptions.map((option) {
                        final selected = _filterSup == option;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(option),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _filterSup = option),
                            showCheckmark: false,
                            selectedColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.1),
                            labelStyle: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w400,
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey[600],
                            ),
                            side: BorderSide(
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey[300]!,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                // Count
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_filteredMembers.length} participantes',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                // List
                Expanded(
                  child: _filteredMembers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline,
                                  size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                'Nenhum membro encontrado',
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _filteredMembers.length,
                          itemBuilder: (context, index) {
                            final member = _filteredMembers[index];
                            final cellName =
                                _cellNames[member.cellId] ?? 'Sem célula';
                            final supId = _cellToSup[member.cellId];
                            final supName = supId != null ? _supNames[supId] : null;
                            return _MemberCard(
                              member: member,
                              cellName: cellName,
                              supervisionName: supName,
                              onTap: () async {
                                final cellProvider =
                                    context.read<CellProvider>();
                                final nav = Navigator.of(context);
                                final doc = await _db
                                    .collection('cells')
                                    .doc(member.cellId)
                                    .get();
                                if (doc.exists && mounted) {
                                  cellProvider.selectCell(
                                      CellGroup.fromFirestore(doc));
                                  nav.pushNamed(
                                    '/edit-member',
                                    arguments: member,
                                  );
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final CellMember member;
  final String cellName;
  final String? supervisionName;
  final VoidCallback onTap;

  const _MemberCard({
    required this.member,
    required this.cellName,
    this.supervisionName,
    required this.onTap,
  });

  String get _roleLabel {
    if (member.isLeader) return 'Líder';
    if (member.isHelper) return 'Auxiliar';
    if (member.isVisitor) return 'Visitante';
    return 'Membro';
  }

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
    final color = _roleColor(theme);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    member.name.isNotEmpty
                        ? member.name[0].toUpperCase()
                        : '?',
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
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            supervisionName != null
                                ? 'Sup. ${supervisionName!.replaceFirst('Supervisão ', '')} · $cellName'
                                : cellName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
