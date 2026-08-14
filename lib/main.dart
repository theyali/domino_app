import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'localization/app_language.dart';
import 'screens/auth_gate_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final languageController = LanguageController();
  await languageController.load();

  runApp(DominoApp(languageController: languageController));
}

class DominoApp extends StatelessWidget {
  final LanguageController languageController;

  const DominoApp({
    super.key,
    required this.languageController,
  });

  @override
  Widget build(BuildContext context) {
    return LanguageScope(
      controller: languageController,
      child: AnimatedBuilder(
        animation: languageController,
        builder: (context, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: Locale(languageController.language.code),
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: const [
              Locale('az'),
              Locale('ru'),
            ],
            home: const AuthGateScreen(),
          );
        },
      ),
    );
  }
}
