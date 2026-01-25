// main.dart
import 'package:flutter/material.dart';

import 'view.dart';
import 'login_screen.dart';
import 'voice_overlay.dart';

void main() => runApp(const BankWorldApp());

class BankWorldApp extends StatelessWidget {
  const BankWorldApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = BankColors.light();
    return BankTheme(
      colors: colors,
      child: MaterialApp(
        title: 'Chameleon Bank',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: colors.surface,
          colorScheme: ColorScheme.light(
            primary: colors.text,
            onPrimary: colors.surface,
            surface: colors.surface,
            onSurface: colors.text,
            outline: colors.divider,
          ),
        ),
        // Wrap with voice overlay for global shake detection
        builder: (context, child) {
          return VoiceCommandOverlay(child: child ?? const SizedBox.shrink());
        },
        home: const LoginScreen(),
      ),
    );
  }
}
