import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/auth_provider.dart';
import 'providers/cell_provider.dart';
import 'providers/hierarchy_provider.dart';

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
          // Decide initial route based on auth + church state
          String initialRoute;
          if (auth.isLoggedIn) {
            initialRoute = AppRoutes.home;
          } else if (auth.hasChurch) {
            initialRoute = AppRoutes.login;
          } else {
            initialRoute = AppRoutes.churchSelection;
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
            initialRoute: initialRoute,
            routes: AppRoutes.routes,
          );
        },
      ),
    );
  }
}
