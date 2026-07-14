import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'screens/library_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
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
        body: Center(
          child: CircularProgressIndicator(
            color: isDark ? AppPalette.dark.navy : AppPalette.light.navy,
          ),
        ),
      );
    }

    return const LibraryScreen();
  }
}
