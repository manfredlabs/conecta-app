import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signIn(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                  children: [
                    // ── Header ──
                    Center(
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 130,
                        height: 130,
                      ),
                    ),
                    const SizedBox(height: 2),
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
                          color: AppColors.neutral500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── E-mail ──
                    Text(
                      'E-mail',
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
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'seu@email.com',
                            hintStyle:
                                const TextStyle(color: AppColors.neutral400),
                            prefixIcon: Icon(Icons.email_outlined,
                                color: primaryColor, size: 20),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Informe seu e-mail';
                            }
                            if (!value.contains('@')) {
                              return 'E-mail inválido';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Senha ──
                    Text(
                      'Senha',
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
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          keyboardType: TextInputType.visiblePassword,
                          enableSuggestions: false,
                          autocorrect: false,
                          decoration: InputDecoration(
                            hintText: 'Sua senha',
                            hintStyle:
                                const TextStyle(color: AppColors.neutral400),
                            prefixIcon: Icon(Icons.lock_outlined,
                                color: primaryColor, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.neutral400,
                                size: 20,
                              ),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Informe sua senha';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),

                    // ── Erro ──
                    Consumer<AuthProvider>(
                      builder: (context, auth, _) {
                        if (auth.error == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            auth.error!,
                            style: TextStyle(
                                color: theme.colorScheme.error, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ── Botão fixo ──
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  return Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      border: Border(
                        top: const BorderSide(
                            color: AppColors.neutral200, width: 1),
                      ),
                    ),
                    child: FilledButton.icon(
                      onPressed: auth.isLoading ? () {} : _handleLogin,
                      icon: SizedBox(
                        width: 20,
                        height: 20,
                        child: auth.isLoading
                            ? const CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.white)
                            : const Icon(Icons.login_rounded, size: 20),
                      ),
                      label: Text(auth.isLoading ? 'Entrando...' : 'Entrar'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
