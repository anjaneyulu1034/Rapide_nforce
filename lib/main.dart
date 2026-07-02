import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_strings.dart';
import 'package:rapide_nforce/core/constants/app_theme.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/theme_service.dart';
import 'package:rapide_nforce/ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.instance.restoreSession();
  await ThemeService.instance.restore();
  runApp(const RapideNforceApp());
}

class RapideNforceApp extends StatelessWidget {
  const RapideNforceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        return MaterialApp(
          key: ValueKey(ThemeService.instance.mode),
          title: AppStrings.appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          home: const AppShell(),
        );
      },
    );
  }
}
