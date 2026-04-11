import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/auth_provider.dart';
import 'providers/cell_provider.dart';
import 'providers/hierarchy_provider.dart';
import 'screens/auth/church_selection_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/shell/main_shell.dart';

class ConectaApp extends StatelessWidget {
  const ConectaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => CellProvider()),
        ChangeNotifierProvider(create: (_) => HierarchyProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          Widget home;
          if (!auth.initialized) {
            home = const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else if (auth.isLoggedIn) {
            home = const MainShell();
          } else if (auth.hasChurch) {
            home = const LoginScreen();
          } else {
            home = const ChurchSelectionScreen();
          }

          return MaterialApp(
            title: 'Conecta',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('pt', 'BR')],
            locale: const Locale('pt', 'BR'),
            home: home,
            routes: AppRoutes.routes,
          );
        },
      ),
    );
  }
}
