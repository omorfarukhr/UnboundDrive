import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/theme/app_theme.dart';
import 'features/auth/data/telegram_auth_service.dart';
import 'features/auth/domain/models/auth_state.dart';
import 'features/auth/presentation/controllers/auth_controller.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/drive/presentation/screens/home_drive_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authService = TelegramAuthService();
  final hasSession = await authService.hasActiveSession();

  runApp(
    ProviderScope(
      child: UnboundDriveApp(initialHasSession: hasSession),
    ),
  );
}

class UnboundDriveApp extends ConsumerWidget {
  final bool initialHasSession;
  const UnboundDriveApp({super.key, this.initialHasSession = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'UnboundDrive',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.darkTheme,
      home: authState.isAuthenticated
          ? const HomeDriveScreen()
          : (initialHasSession && authState.status == AuthStatus.initial)
              ? const HomeDriveScreen()
              : const LoginScreen(),
    );
  }
}
