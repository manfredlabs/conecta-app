import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/bulletin_model.dart';
import '../../models/user_model.dart';

class BulletinTab extends StatefulWidget {
  const BulletinTab({super.key});

  @override
  State<BulletinTab> createState() => _BulletinTabState();
}

class _BulletinTabState extends State<BulletinTab> {
  final _service = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.appUser;
    if (user == null) return const Center(child: CircularProgressIndicator());

    final isAdmin = user.role == UserRole.admin;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Text(
                'Boletim',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Bulletin>>(
                stream: _service.getBulletins(churchId: auth.churchId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final bulletins = snap.data ?? [];
                  if (bulletins.isEmpty) {
                    return _emptyState();
                  }

                  return _buildBulletinList(bulletins, isAdmin);
                },
              ),
            ),
          ],
        ),
        floatingActionButton: isAdmin
            ? FloatingActionButton.extended(
                onPressed: () => _showUploadModal(context),
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('Enviar'),
              )
            : null,
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Nenhum boletim disponível',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'O admin pode enviar boletins semanais',
            style: TextStyle(color: Colors.grey[350], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletinList(List<Bulletin> bulletins, bool isAdmin) {
    // Separar: boletim da semana vs anteriores
    final currentWeek = bulletins.where((b) => b.isCurrentWeek).toList();
    final previous = bulletins.where((b) => !b.isCurrentWeek).toList();

    final hasCurrentWeek = currentWeek.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      children: [
        // Card destaque da semana
        _buildWeekHighlight(hasCurrentWeek ? currentWeek.first : null, isAdmin),
        if (previous.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Anteriores',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          ...previous.asMap().entries.map((entry) {
            final widgets = <Widget>[];
            if (entry.key > 0) widgets.add(const SizedBox(height: 8));
            widgets.add(_buildBulletinCard(entry.value, isAdmin));
            return Column(children: widgets);
          }),
        ],
      ],
    );
  }

  Widget _buildWeekHighlight(Bulletin? bulletin, bool isAdmin) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    if (bulletin == null) {
      // Nenhum boletim esta semana
      return Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.orange.withValues(alpha: 0.4), width: 1.5),
        ),
        color: Colors.orange.withValues(alpha: 0.03),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sem boletim esta semana',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Semana ${_currentWeekLabel()}',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Boletim da semana existe — card em destaque
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primaryColor.withValues(alpha: 0.4), width: 1.5),
      ),
      color: primaryColor.withValues(alpha: 0.03),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openBulletin(bulletin),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_fileIcon(bulletin.fileType), color: primaryColor, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Esta semana',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bulletin.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isAdmin)
                    _deleteButton(bulletin),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    bulletin.weekLabel,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.insert_drive_file_outlined, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    bulletin.fileType.toUpperCase(),
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openBulletin(bulletin),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Abrir boletim'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBulletinCard(Bulletin bulletin, bool isAdmin) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openBulletin(bulletin),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _fileIcon(bulletin.fileType),
                  color: Colors.grey[600],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bulletin.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${bulletin.weekLabel}  ·  ${bulletin.fileType.toUpperCase()}',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              if (isAdmin) _deleteButton(bulletin),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _deleteButton(Bulletin bulletin) {
    return IconButton(
      icon: Icon(Icons.delete_outline, color: Colors.red[300], size: 20),
      onPressed: () => _confirmDelete(bulletin),
      tooltip: 'Excluir boletim',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  // ─── Ações ───

  Future<void> _openBulletin(Bulletin bulletin) async {
    // Baixar e abrir o arquivo
    _showLoadingDialog('Abrindo...');
    try {
      final dir = await _getTemporaryDirectory();
      final filePath = '${dir.path}/${bulletin.fileName}';
      final file = File(filePath);

      if (!await file.exists()) {
        // Download do Storage
        final ref = FirestoreService().storageRef(bulletin.storagePath);
        await ref.writeToFile(file);
      }

      if (mounted) Navigator.of(context).pop(); // dismiss loading
      await OpenFilex.open(filePath);
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao abrir: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<Directory> _getTemporaryDirectory() async {
    final dir = await Directory.systemTemp.createTemp('bulletin_');
    return dir;
  }

  Future<void> _confirmDelete(Bulletin bulletin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir boletim?'),
        content: Text('Tem certeza que deseja excluir "${bulletin.title}"?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.deleteBulletin(bulletin.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Boletim excluído')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showUploadModal(BuildContext context) {
    final titleController = TextEditingController();
    PlatformFile? selectedFile;
    bool uploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Enviar boletim',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Título',
                      hintText: 'Ex: Boletim 07/04 - 13/04',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  // File picker
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'doc', 'docx'],
                      );
                      if (result != null && result.files.isNotEmpty) {
                        setModalState(() => selectedFile = result.files.first);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedFile != null
                                ? _fileIcon(selectedFile!.extension ?? 'pdf')
                                : Icons.attach_file_rounded,
                            color: selectedFile != null
                                ? Theme.of(ctx).colorScheme.primary
                                : Colors.grey[500],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selectedFile?.name ?? 'Selecionar arquivo (PDF ou Word)',
                              style: TextStyle(
                                color: selectedFile != null
                                    ? const Color(0xFF2D3436)
                                    : Colors.grey[500],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (selectedFile != null)
                            Icon(Icons.check_circle, color: Colors.green[400], size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: uploading || selectedFile == null
                          ? null
                          : () async {
                              final title = titleController.text.trim();
                              if (title.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Informe o título')),
                                );
                                return;
                              }
                              setModalState(() => uploading = true);
                              await _uploadBulletin(title, selectedFile!);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                      child: uploading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Enviar'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _uploadBulletin(String title, PlatformFile platformFile) async {
    final auth = context.read<AuthProvider>();
    final churchId = auth.churchId ?? '';
    final userId = auth.appUser?.id ?? '';

    try {
      final file = File(platformFile.path!);
      final fileName = platformFile.name;
      final ext = platformFile.extension ?? 'pdf';

      // Cria doc no Firestore primeiro pra ter o ID
      final weekStart = Bulletin.currentWeekStart();
      final bulletin = Bulletin(
        id: '',
        title: title,
        fileName: fileName,
        fileUrl: '',
        storagePath: '',
        fileType: ext.toLowerCase(),
        churchId: churchId,
        uploadedBy: userId,
        weekStart: weekStart,
        createdAt: DateTime.now(),
      );

      final bulletinId = await _service.addBulletin(bulletin);

      // Upload do arquivo
      final (url, path) = await _service.uploadBulletinFile(
        churchId: churchId,
        bulletinId: bulletinId,
        fileName: fileName,
        file: file,
      );

      // Atualiza doc com URL e path do Storage
      await FirestoreService().updateBulletinUrls(
        bulletinId: bulletinId,
        fileUrl: url,
        storagePath: path,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Boletim enviado com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      ),
    );
  }

  String _currentWeekLabel() {
    final monday = Bulletin.currentWeekStart();
    final sunday = monday.add(const Duration(days: 6));
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(monday.day)}/${pad(monday.month)} - ${pad(sunday.day)}/${pad(sunday.month)}';
  }

  IconData _fileIcon(String fileType) {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx':
        return Icons.description_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}
