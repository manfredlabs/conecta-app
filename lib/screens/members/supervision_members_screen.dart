import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/hierarchy_provider.dart';
import '../../providers/cell_provider.dart';
import '../../models/cell_member_model.dart';
import '../../models/cell_model.dart';

class SupervisionMembersScreen extends StatefulWidget {
  const SupervisionMembersScreen({super.key});

  @override
  State<SupervisionMembersScreen> createState() =>
      _SupervisionMembersScreenState();
}

class _SupervisionMembersScreenState extends State<SupervisionMembersScreen> {
  final _db = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  List<CellMember> _members = [];
  Map<String, String> _cellNames = {};
  bool _loading = true;
  String _searchQuery = '';
  String _filterCell = 'Todas';
  List<String> _cellFilterOptions = ['Todas'];

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
    final supervision = hierarchy.selectedSupervision;
    if (supervision == null) return;

    final cellsSnap = await _db
        .collection('cells')
        .where('supervisionId', isEqualTo: supervision.id)
        .get();
    final cells =
        cellsSnap.docs.map((d) => CellGroup.fromFirestore(d)).toList();
    final cellNames = {for (var c in cells) c.id: c.name};

    final membersSnap = await _db
        .collection('cell_members')
        .where('supervisionId', isEqualTo: supervision.id)
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
        _cellFilterOptions = ['Todas', ...cellNames.values.toList()..sort()];
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
    if (_filterCell != 'Todas') {
      final cellId = _cellNames.entries
          .where((e) => e.value == _filterCell)
          .map((e) => e.key)
          .firstOrNull;
      if (cellId != null) {
        list = list.where((m) => m.cellId == cellId).toList();
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final hierarchy = context.watch<HierarchyProvider>();
    final supervision = hierarchy.selectedSupervision;

    return Scaffold(
      appBar: AppBar(
        title: Text(supervision?.name ?? 'Participantes'),
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
                // Cell filter chips
                if (_cellFilterOptions.length > 2)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                    child: Row(
                      children: _cellFilterOptions.map((option) {
                        final selected = _filterCell == option;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(option),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _filterCell = option),
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
                            return _MemberCard(
                              member: member,
                              cellName: cellName,
                              onTap: () async {
                                final cellProvider =
                                    context.read<CellProvider>();
                                final doc = await _db
                                    .collection('cells')
                                    .doc(member.cellId)
                                    .get();
                                if (doc.exists && mounted) {
                                  cellProvider.selectCell(
                                      CellGroup.fromFirestore(doc));
                                  Navigator.pushNamed(
                                    context,
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
  final VoidCallback onTap;

  const _MemberCard({
    required this.member,
    required this.cellName,
    required this.onTap,
  });

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
                            cellName,
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
