import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/connections_provider.dart';
import 'providers/terminal_provider.dart';
import 'providers/keyboard_provider.dart';
import 'screens/auth_screen.dart';

class CTermApp extends StatelessWidget {
  const CTermApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B8DEF),
      brightness: Brightness.dark,
      surface: const Color(0xFF1C1C1E),
      surfaceContainerHighest: const Color(0xFF2C2C2E),
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionsProvider()),
        ChangeNotifierProvider(create: (_) => TerminalProvider()),
        ChangeNotifierProvider(create: (_) => KeyboardProvider()),
      ],
      child: MaterialApp(
        title: 'koder',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: colorScheme,
          scaffoldBackgroundColor: colorScheme.surface,
          appBarTheme: AppBarTheme(
            backgroundColor: colorScheme.surfaceContainerHighest,
            foregroundColor: colorScheme.onSurface,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
          ),
          cardTheme: CardTheme(
            color: colorScheme.surfaceContainerHighest,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.primary,
            ),
          ),
          dialogTheme: DialogTheme(
            backgroundColor: colorScheme.surfaceContainerHighest,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return colorScheme.primary;
              }
              return colorScheme.outline;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return colorScheme.primaryContainer;
              }
              return colorScheme.surfaceContainerHighest;
            }),
          ),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: colorScheme.inverseSurface,
            contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          popupMenuTheme: PopupMenuThemeData(
            color: colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          listTileTheme: ListTileThemeData(
            iconColor: colorScheme.onSurfaceVariant,
            textColor: colorScheme.onSurface,
          ),
          dividerTheme: DividerThemeData(
            color: colorScheme.outlineVariant,
            thickness: 1,
          ),
        ),
        home: const AuthScreen(),
      ),
    );
  }
}
