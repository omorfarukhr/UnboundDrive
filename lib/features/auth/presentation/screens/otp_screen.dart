import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/models/auth_state.dart';
import '../controllers/auth_controller.dart';
import 'two_factor_screen.dart';
import '../../../drive/presentation/screens/home_drive_screen.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phoneNumber;

  const OtpScreen({super.key, required this.phoneNumber});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _onCodeChanged(String value) {
    if (value.trim().length == 5) {
      ref.read(authControllerProvider.notifier).verifyCode(value.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    // Listen for auth state transitions
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.status == AuthStatus.waitingFor2FA) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TwoFactorScreen(phoneNumber: widget.phoneNumber),
          ),
        );
      } else if (next.status == AuthStatus.authenticated) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeDriveScreen()),
          (route) => false,
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.mark_email_read_rounded, color: AppColors.accent, size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                "Enter Verification Code",
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Telegram sent a code to your other devices or via SMS to ${widget.phoneNumber}",
                style: const TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 32),

              // Code Input Field
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 5,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 16,
                ),
                decoration: InputDecoration(
                  counterText: "",
                  hintText: "•••••",
                  hintStyle: TextStyle(
                    color: AppColors.textMuted.withValues(alpha: 0.4),
                    letterSpacing: 16,
                  ),
                ),
                onChanged: _onCodeChanged,
              ),

              if (authState.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  authState.errorMessage!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: authState.isLoading
                      ? null
                      : () => _onCodeChanged(_codeController.text),
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Verify & Enter Vault", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 20),
              Center(
                child: TextButton.icon(
                  onPressed: authState.isLoading
                      ? null
                      : () {
                          ref.read(authControllerProvider.notifier).sendCode(
                                phoneNumber: widget.phoneNumber,
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("New code sent!")),
                          );
                        },
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.accent),
                  label: const Text(
                    "Resend code",
                    style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
