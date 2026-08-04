import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'billing/auth_controller.dart';
import 'billing/entitlement_controller.dart';
import 'billing/purchase_service.dart';
import 'billing/supabase_config.dart';
import 'live/live_controller.dart';
import 'screens/library_screen.dart';
import 'theme.dart';
import 'ui_kit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only when this build carries credentials. Without them the app is exactly
  // what it always was — offline, no account, nothing gated — so there is
  // nothing to connect to and no reason to delay the first frame.
  if (billingConfigured) {
    try {
      await Supabase.initialize(
        url: kSupabaseUrl,
        publishableKey: kSupabaseAnonKey,
      );
    } catch (_) {
      // A failed init must not stop the hymnal from opening. The entitlement
      // controller falls back to its cache, and the gate lets grandfathered
      // and cached-subscriber users through as usual.
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..init()),
        ChangeNotifierProvider(create: (_) => LiveSessionController()),
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(
          create: (_) => EntitlementController(
            source: billingConfigured ? SupabaseEntitlementSource() : null,
          )..init(),
        ),
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
