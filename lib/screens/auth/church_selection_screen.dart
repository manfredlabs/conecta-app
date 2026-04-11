import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';

class ChurchSelectionScreen extends StatefulWidget {
  const ChurchSelectionScreen({super.key});

  @override
  State<ChurchSelectionScreen> createState() => _ChurchSelectionScreenState();
}

class _ChurchSelectionScreenState extends State<ChurchSelectionScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _findChurch() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Informe o código da igreja.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final church = await FirestoreService().getChurchByCode(code);
      if (church == null) {
        setState(() => _error = 'Igreja não encontrada. Verifique o código.');
        return;
      }

      if (mounted) {
        await context.read<AuthProvider>().setChurchId(church.id);
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      setState(() => _error = 'Erro ao buscar igreja. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                children: [
                  // ── Header ──
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.church_rounded,
                          size: 40, color: primaryColor),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Conecta',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Gestão de Células',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ── Código da igreja ──
                  Text(
                    'Código da Igreja',
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
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: TextField(
                        controller: _codeController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _findChurch(),
                        decoration: InputDecoration(
                          hintText: 'Ex: maranata-sp',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.key_rounded,
                              color: primaryColor, size: 20),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),

                  // ── Erro ──
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(
                            color: theme.colorScheme.error, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),

            // ── Botão fixo ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: FilledButton.icon(
                onPressed: _loading ? null : _findChurch,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.arrow_forward_rounded, size: 20),
                label: Text(_loading ? 'Buscando...' : 'Continuar'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
