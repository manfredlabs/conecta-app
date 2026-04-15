import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../models/bulletin_model.dart';
import '../../models/user_model.dart';
import '../../config/theme.dart';

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
            ? FloatingActionButton(
                heroTag: 'bulletin_fab',
                onPressed: () => _showUploadModal(context),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: AppColors.white,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, size: 28),
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
          Icon(Icons.article_outlined, size: 64, color: AppColors.neutral300),
          
          const SizedBox(height: 16),
          Text(
            'Nenhum documento disponível',
            style: const TextStyle(color: AppColors.neutral400, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'O admin pode enviar documentos',
            style: const TextStyle(color: AppColors.neutral500, fontSize: 13),
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
              style: const TextStyle(color: AppColors.neutral400, fontSize: 14),
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
        color: AppColors.neutral600,
          ),
    );
  }


  Widget _buildBulletinCard(Bulletin bulletin, bool isAdmin, {bool highlighted = false}) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final iconColor = highlighted ? primaryColor : AppColors.neutral600;

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
                      style: theme.textTheme.bodySmall?.copyWith(color: AppColors.neutral500),
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.more_vert, color: AppColors.neutral400, size: 22),
                  onPressed: () => _showAdminActions(bulletin),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              if (!isAdmin)
                const Icon(Icons.chevron_right, color: AppColors.neutral400),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Ações ───

  void _showAdminActions(Bulletin bulletin) {
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
            Text(
              bulletin.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _actionTile(
              icon: Icons.edit_outlined,
              label: 'Renomear',
              color: Theme.of(context).colorScheme.primary,
              onTap: () {
                Navigator.pop(ctx);
                _showRenameSheet(bulletin);
              },
            ),
            const SizedBox(height: 8),
            _actionTile(
              icon: Icons.delete_outline,
              label: 'Excluir',
              color: Colors.red,
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteSheet(bulletin);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameSheet(Bulletin bulletin) {
    final controller = TextEditingController(text: bulletin.title);
    bool saving = false;

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
                24, 28, 24, MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
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
                      color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 28,
                      color: Theme.of(ctx).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Renomear documento',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Título'),
                    textCapitalization: TextCapitalization.sentences,
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
                          onPressed: saving
                              ? null
                              : () async {
                                  final newTitle = controller.text.trim();
                                  if (newTitle.isEmpty) return;
                                  setModalState(() => saving = true);
                                  await _service.updateBulletinTitle(
                                    bulletinId: bulletin.id,
                                    title: newTitle,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Documento renomeado')),
                                    );
                                  }
                                },
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                              : const Text('Salvar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteSheet(Bulletin bulletin) {
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
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.delete_outline,
                size: 28,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Excluir documento?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Tem certeza que deseja excluir "${bulletin.title}"? Esta ação não pode ser desfeita.',
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
                    onPressed: () async {
                      Navigator.pop(ctx);
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
                            const SnackBar(content: Text('Não foi possível excluir o documento')),
                          );
                        }
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.error,
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

  Future<void> _openBulletin(Bulletin bulletin) async {
    if (bulletin.storagePath.isEmpty || bulletin.fileUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível localizar o arquivo na base de dados')),
        );
      }
      return;
    }

    _showLoadingDialog();
    try {
      final dir = await _getTemporaryDirectory();
      final filePath = '${dir.path}/${bulletin.fileName}';
      final file = File(filePath);

      if (!await file.exists()) {
        final ref = _service.storageRef(bulletin.storagePath);
        await ref.writeToFile(file);
      }

      if (mounted) Navigator.of(context).pop();
      await OpenFilex.open(filePath);
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o documento. Tente novamente.')),
        );
      }
    }
  }

  Future<Directory> _getTemporaryDirectory() async {
    final dir = Directory('${Directory.systemTemp.path}/conecta_docs');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }


  void _showUploadModal(BuildContext context) {
    final titleController = TextEditingController();
    PlatformFile? selectedFile;
    bool uploading = false;
    final primaryColor = Theme.of(context).colorScheme.primary;

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
                24, 28, 24, MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
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
                      Icons.upload_file_rounded,
                      size: 28,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Enviar documento',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'PDF ou Word',
                    style: const TextStyle(fontSize: 13, color: AppColors.neutral500),
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
                        border: Border.all(color: AppColors.neutral300),
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.white,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selectedFile != null
                                ? _fileIcon(selectedFile!.extension ?? 'pdf')
                                : Icons.attach_file_rounded,
                            color: selectedFile != null
                                ? primaryColor
                              : AppColors.neutral500,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selectedFile?.name ?? 'Selecionar arquivo',
                              style: TextStyle(
                                color: selectedFile != null
                                    ? AppColors.textDark
                                    : AppColors.neutral500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (selectedFile != null)
                            const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: uploading ? null : () => Navigator.pop(ctx),
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
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: uploading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                              : const Text('Enviar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
      if (platformFile.path == null) {
        throw Exception('Não foi possível acessar o caminho do arquivo.');
      }
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
      await _service.updateBulletinUrls(
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
          SnackBar(content: Text('Erro ao enviar: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showLoadingDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 20),
              Text(
                'Abrindo documento...',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
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
