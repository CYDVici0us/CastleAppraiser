import 'package:btcc/src/screens/main_screen.dart';
import 'package:flutter/material.dart';

/// Shared surfaces for cards that sit on the dark gray scaffold.
class AppColors {
  AppColors._();

  /// Dark blue card / castle chrome (shows behind empty grid cells).
  static const Color card = Color(0xFF1B2A40);

  /// Slightly elevated card variant.
  static const Color cardElevated = Color(0xFF243752);
}

class AppWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Btcc',
        home: MainScreen(),
        themeMode: ThemeMode.dark,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121212),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1E88E5),
            brightness: Brightness.dark,
            surface: const Color(0xFF121212),
            primary: const Color(0xFF42A5F5),
            secondary: const Color(0xFF64B5F6),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF121212),
            foregroundColor: Colors.white,
            elevation: 0,
            titleSpacing: 0,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF1E88E5),
            foregroundColor: Colors.white,
          ),
          cardTheme: const CardThemeData(
            color: AppColors.card,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: AppColors.cardElevated,
          ),
          popupMenuTheme: const PopupMenuThemeData(
            color: AppColors.cardElevated,
          ),
        ),
      );
}
