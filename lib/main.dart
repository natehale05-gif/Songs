import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'billing/entitlement_controller.dart';
import 'billing/purchase_service.dart';
import 'live/live_controller.dart';
import 'screens/library_screen.dart';
import 'theme.dart';
import 'ui_kit.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..init()),
        ChangeNotifierProvider(create: (_) => LiveSessionController()),
        ChangeNotifierProvider(
            create: (_) => EntitlementController()..init()),
        // Replaced per platform once billing is configured; see
        // docs/billing-setup.md.
        Provider<PurchaseService>(
            create: (_) => const UnconfiguredPurchaseService()),
      ],
      child: const SongsApp(),
    ),
  );
}

class SongsApp extends StatelessWidget {
  const SongsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = state.theme == AppThemeMode.dark;
    final palette = isDark ? AppPalette.dark : AppPalette.light;

    return MaterialApp(
      title: 'Songs of the Church',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: _buildTheme(palette),
      home: const _Root(),
    );
  }

  ThemeData _buildTheme(AppPalette p) {
    final base = p.brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
    return base.copyWith(
      scaffoldBackgroundColor: p.bg,
      colorScheme: base.colorScheme.copyWith(
        primary: p.navy,
        secondary: p.accent,
        surface: p.surface,
        brightness: p.brightness,
      ),
      pageTransitionsTheme: kAppPageTransitions,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textTheme: base.textTheme.apply(
        bodyColor: p.label,
        displayColor: p.label,
        fontFamily: 'SF Pro Text',
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = state.theme == AppThemeMode.dark;

    SystemChrome.setSystemUIOverlayStyle(
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    );

    if (!state.isLoaded) {
      return Scaffold(
        backgroundColor: isDark ? AppPalette.dark.bg : AppPalette.light.bg,
        body: const Center(
          child: CupertinoActivityIndicator(radius: 14),
        ),
      );
    }

    return const LibraryScreen();
  }
}
