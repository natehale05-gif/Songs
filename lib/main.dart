import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/library_controller.dart';
import 'theme.dart';
import 'ui/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SongsApp());
}

class SongsApp extends StatelessWidget {
  const SongsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LibraryController>(
      create: (_) => LibraryController()..init(),
      child: MaterialApp(
        title: 'Songs',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const HomeScreen(),
      ),
    );
  }
}
