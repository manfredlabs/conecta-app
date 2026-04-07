import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cell_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/cell_member_model.dart';
import '../../models/person_model.dart';

class AddMemberScreen extends StatefulWidget {
  const AddMemberScreen({super.key});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  String _gender = 'M';
  DateTime? _birthDate;
  bool _birthDateExpanded = false;
  bool _isVisitor = true;
  bool _saving = false;

  // Member search state
  List<CellMember> _allMembers = [];
  Map<String, String> _cellNames = {};
  Map<String, String> _nameRoles = {};
  List<CellMember> _filteredMembers = [];
  CellMember? _selectedMember;
  bool _loadingMembers = false;

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllMembers() async {
    setState(() => _loadingMembers = true);
    final firestoreService = FirestoreService();
    final members = await firestoreService.searchAllActiveCellMembers();
    final cellIds = members.map((m) => m.cellId).toSet();
    final results = await Future.wait([
      firestoreService.getCellNames(cellIds),
      firestoreService.getUserRolesByName(),
    ]);

    if (mounted) {
      setState(() {
        _allMembers = members;
        _cellNames = results[0];
        _nameRoles = results[1];
        _loadingMembers = false;
      });
      // Re-filter with current search text
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
    final cell = context.read<CellProvider>().selectedCell!;

    setState(() {
      _filteredMembers = _allMembers
          .where((m) =>
              m.name.toLowerCase().contains(q) &&
              m.cellId != cell.id)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      // Deduplicate by name (same person in multiple cells)
      final seen = <String>{};
      _filteredMembers = _filteredMembers.where((m) {
        final key = m.name.toLowerCase();
        if (seen.contains(key)) return false;
        seen.add(key);
        return true;
      }).toList();
    });
  }

  void _selectMember(CellMember member) {
    setState(() {
      _selectedMember = member;
      _searchController.text = member.name;
      _filteredMembers = [];
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedMember = null;
      _searchController.clear();
      _filteredMembers = [];
    });
  }

  String? _getRoleBadge(CellMember member) {
    // Check user role by name match (pastor, supervisor)
    final role = _nameRoles[member.name.toLowerCase()];
    if (role == 'pastor') return 'Pastor';
    if (role == 'supervisor') return 'Supervisor';
    // Then member-level roles
    if (member.isLeader) return 'Líder';
    if (member.isHelper) return 'Auxiliar';
    return null;
  }


  Future<void> _save() async {
    if (_isVisitor) {
      // Visitor: validate form
      if (!_formKey.currentState!.validate()) return;
    } else {
      // Member: must have selected someone
      if (_selectedMember == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selecione um membro existente da igreja.'),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);

    final cellProvider = context.read<CellProvider>();
    final cell = cellProvider.selectedCell!;

    if (_isVisitor) {
      final person = Person(
        id: '',
        name: _nameController.text.trim(),
        congregationId: cell.congregationId,
        gender: _gender,
        baptized: false,
        birthDate: _birthDate,
      );
      await cellProvider.addPersonAndCellMember(
        person: person,
        cellId: cell.id,
        supervisionId: cell.supervisionId,
        congregationId: cell.congregationId,
        isVisitor: true,
      );
    } else {
      // Add existing person to this cell
      final src = _selectedMember!;
      final firestoreService = FirestoreService();
      await firestoreService.addPersonToCell(
        personId: src.personId,
        personName: src.name,
        cellId: cell.id,
        supervisionId: cell.supervisionId,
        congregationId: cell.congregationId,
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isVisitor
              ? 'Visitante adicionado!'
              : 'Membro adicionado!'),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isVisitor ? 'Novo Visitante' : 'Novo Membro'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                children: [
                  // ── Tipo ──
                  Text(
                    'Tipo',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _TypeOption(
                          label: 'Visitante',
                          icon: Icons.person_outline,
                          selected: _isVisitor,
                          color: theme.colorScheme.secondary,
                          onTap: () => setState(() => _isVisitor = true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _TypeOption(
                          label: 'Membro',
                          icon: Icons.person,
                          selected: !_isVisitor,
                          color: theme.colorScheme.tertiary,
                          onTap: () {
                            setState(() => _isVisitor = false);
                            if (_allMembers.isEmpty) _loadAllMembers();
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  if (_isVisitor) ...[
                    // ══════════════════════════════
                    // VISITOR FORM
                    // ══════════════════════════════

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
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Informe o nome';
                            }
                            if (value.trim().length < 3) {
                              return 'Nome deve ter pelo menos 3 caracteres';
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
                    Row(
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
                    Card(
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
                              initialDate:
                                  _birthDate ?? DateTime(2000, 1, 1),
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
                  ] else ...[
                    // ══════════════════════════════
                    // MEMBER SEARCH
                    // ══════════════════════════════

                    if (_selectedMember != null) ...[
                      // ── Selected member card ──
                      Text(
                        'Membro selecionado',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor:
                                    primaryColor.withValues(alpha: 0.1),
                                child: Text(
                                  _selectedMember!.name.isNotEmpty
                                      ? _selectedMember!.name[0].toUpperCase()
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
                                      _selectedMember!.name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _cellNames[_selectedMember!.cellId] !=
                                              null
                                          ? '${_cellNames[_selectedMember!.cellId]}'
                                          : 'Sem célula',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              color: Colors.grey[500]),
                                    ),
                                    if (_getRoleBadge(_selectedMember!) != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: primaryColor
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            _getRoleBadge(_selectedMember!)!,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: primaryColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close_rounded,
                                    color: Colors.grey[400]),
                                onPressed: _clearSelection,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // ── Search field ──
                      Text(
                        'Buscar membro',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _searchController,
                            textCapitalization: TextCapitalization.words,
                            onChanged: _filterMembers,
                            decoration: InputDecoration(
                              hintText: 'Digite o nome do membro',
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
                              prefixIconConstraints: const BoxConstraints(
                                  minWidth: 36, minHeight: 0),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.close,
                                          size: 18, color: Colors.grey[400]),
                                      onPressed: _clearSelection,
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
                          final cellName =
                              _cellNames[member.cellId] ?? '';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Card(
                              margin: EdgeInsets.zero,
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
                                        backgroundColor: primaryColor
                                            .withValues(alpha: 0.1),
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
                                            if (cellName.isNotEmpty)
                                              Text(
                                                cellName,
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
                                            color: primaryColor
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(6),
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
                                      Icon(Icons.add_circle_outline_rounded,
                                          color: Colors.grey[400], size: 22),
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
                ],
              ),
            ),

            // ── Botão Salvar (fixo no bottom) ──
            if (_isVisitor || _selectedMember != null)
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
                    label: Text(
                      _isVisitor ? 'Adicionar Visitante' : 'Adicionar Membro',
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
