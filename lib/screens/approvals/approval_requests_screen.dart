import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/approval_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/role_colors.dart';
import '../../config/theme.dart';

class ApprovalRequestsScreen extends StatelessWidget {
  const ApprovalRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final churchId = context.read<AuthProvider>().churchId;

    return Scaffold(
      appBar: AppBar(title: const Text('Solicitações')),
      body: StreamBuilder<List<ApprovalRequest>>(
        stream: FirestoreService().getPendingApprovalRequests(churchId: churchId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 64, color: AppColors.neutral300),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma solicitação pendente',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.neutral500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tudo em dia!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.neutral400,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final req = requests[index];
              return _RequestCard(key: ValueKey(req.id), request: req);
            },
          );
        },
      ),
    );
  }
}

class _RequestCard extends StatefulWidget {
  final ApprovalRequest request;

  const _RequestCard({super.key, required this.request});

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  bool _loading = false;

  Future<void> _approve() async {
    final confirmed = await _showConfirmModal(
      title: 'Aprovar promoção?',
      subtitle:
          '${widget.request.personName} será promovido(a) a membro da célula ${widget.request.cellName}.',
      icon: Icons.check_circle_rounded,
      iconColor: Theme.of(context).colorScheme.secondary,
      confirmLabel: 'Aprovar',
      confirmColor: Theme.of(context).colorScheme.secondary,
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    final userId = context.read<AuthProvider>().appUser?.id ?? '';
    try {
      await FirestoreService().approveRequest(widget.request.id, changedBy: userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${widget.request.personName} agora é membro!')),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    final confirmed = await _showConfirmModal(
      title: 'Rejeitar solicitação?',
      subtitle:
          '${widget.request.personName} continuará como visitante na célula ${widget.request.cellName}.',
      icon: Icons.cancel_rounded,
      iconColor: AppColors.error,
      confirmLabel: 'Rejeitar',
      confirmColor: AppColors.error,
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    final userId = context.read<AuthProvider>().appUser?.id ?? '';
    try {
      await FirestoreService().rejectRequest(widget.request.id, changedBy: userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitação rejeitada')),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool?> _showConfirmModal({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showModalBottomSheet<bool>(
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
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 28, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.neutral500),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
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
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: confirmColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(confirmLabel),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final req = widget.request;
    final timeSince = DateTime.now().difference(req.createdAt);
    final timeText = timeSince.inDays > 0
        ? 'há ${timeSince.inDays}d'
        : timeSince.inHours > 0
            ? 'há ${timeSince.inHours}h'
            : 'há ${timeSince.inMinutes}min';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: RoleColors.visitor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: RoleColors.visitor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.personName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Visitante → Membro',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: RoleColors.visitor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  timeText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.neutral400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.neutral200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.church_rounded,
                      size: 16, color: AppColors.neutral500),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      req.cellName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.neutral600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(Icons.person_outline_rounded,
                      size: 16, color: AppColors.neutral500),
                  const SizedBox(width: 4),
                  Text(
                    req.requestedByName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.neutral500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _reject,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Rejeitar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error.withValues(alpha: 0.35)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _approve,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Aprovar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
