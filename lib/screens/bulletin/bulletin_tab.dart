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
                'Documentos',
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
            'Nenhum documento disponível',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'O admin pode enviar documentos',
            style: TextStyle(color: Colors.grey[350], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletinList(List<Bulletin> bulletins, bool isAdmin) {
    final thisWeek = bulletins.where((b) => b.isCurrentWeek).toList();
    final previous = bulletins.where((b) => !b.isCurrentWeek).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      children: [
        // Esta semana
        _sectionTitle('Esta semana'),
        const SizedBox(height: 8),
        if (thisWeek.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Nenhum documento esta semana',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ),
        ...thisWeek.asMap().entries.map((e) {
          return Padding(
            padding: EdgeInsets.only(top: e.key > 0 ? 8 : 0),
            child: _buildBulletinCard(e.value, isAdmin, highlighted: true),
          );
        }),
        // Anteriores
        if (previous.isNotEmpty) ...[
          const SizedBox(height: 24),
          _sectionTitle('Anteriores'),
          const SizedBox(height: 8),
          ...previous.asMap().entries.map((e) {
            return Padding(
              padding: EdgeInsets.only(top: e.key > 0 ? 8 : 0),
              child: _buildBulletinCard(e.value, isAdmin),
            );
          }),
        ],
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
    );
  }


  Widget _buildBulletinCard(Bulletin bulletin, bool isAdmin, {bool highlighted = false}) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final iconColor = highlighted ? primaryColor : Colors.grey[600]!;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: highlighted ? primaryColor.withValues(alpha: 0.04) : null,
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
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _fileIcon(bulletin.fileType),
                  color: iconColor,
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
                      '${_formatDate(bulletin.createdAt)}  ·  ${bulletin.fileType.toUpperCase()}',
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
      tooltip: 'Excluir documento',
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
        title: const Text('Excluir documento?'),
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
            const SnackBar(content: Text('Documento excluído')),
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
                    'Enviar documento',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Título',
                      hintText: 'Ex: Boletim Semanal 07/04',
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
          const SnackBar(content: Text('Documento enviado com sucesso!')),
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

  String _formatDate(DateTime date) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(date.day)}/${pad(date.month)}/${date.year}';
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
