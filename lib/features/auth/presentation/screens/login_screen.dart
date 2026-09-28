import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/country_codes.dart';
import '../../domain/models/auth_state.dart';
import '../controllers/auth_controller.dart';
import '../widgets/country_picker_sheet.dart';
import 'otp_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  CountryCode _selectedCountry = CountryCodes.all.first; // Default US, fully changeable

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CountryPickerSheet(
        onCountrySelected: (country) {
          setState(() => _selectedCountry = country);
        },
      ),
    );
  }

  void _onContinue() {
    final rawNumber = _phoneController.text.trim();
    if (rawNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid phone number.")),
      );
      return;
    }

    final fullNumber = "${_selectedCountry.dialCode}$rawNumber";
    ref.read(authControllerProvider.notifier).sendCode(phoneNumber: fullNumber);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    // Listen for code sent transition
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.status == AuthStatus.codeSent && next.phoneNumber != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpScreen(phoneNumber: next.phoneNumber!),
          ),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // App Logo / Symbol
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 24),
                const Text(
                  "UnboundDrive",
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Infinite personal cloud storage. Zero monthly subscriptions. Break free from 15GB limits forever.",
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 36),

                const Text(
                  "Phone Number",
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: AppColors.textLight, fontSize: 16),
                  decoration: InputDecoration(
                    prefixIcon: InkWell(
                      onTap: _showCountryPicker,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_selectedCountry.flag, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 6),
                            Text(
                              _selectedCountry.dialCode,
                              style: const TextStyle(
                                color: AppColors.textLight,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textMuted, size: 20),
                          ],
                        ),
                      ),
                    ),
                    hintText: "1700 000000",
                  ),
                  onSubmitted: (_) => _onContinue(),
                ),

                if (authState.errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    authState.errorMessage!,
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ],

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : _onContinue,
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text("Continue with Telegram", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined, color: AppColors.accent, size: 16),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        "End-to-End Encrypted & Private Vault",
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
