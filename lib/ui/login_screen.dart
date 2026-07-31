import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_strings.dart';
import 'package:rapide_nforce/core/utils/app_toast.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/services/theme_service.dart';
import 'package:rapide_nforce/ui/widgets/brand_logo.dart';
import 'package:rapide_nforce/core/constants/app_gradients.dart';
import 'package:rapide_nforce/ui/widgets/web_ui.dart';

/// Login-only background — a soft red-to-charcoal gradient echoing the
/// brand's red "R" logo, distinct from the flat neutral [AppGradients]
/// background used on every other screen.
LinearGradient get _loginBackgroundGradient => ThemeService.instance.isLight
    ? const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFBE4E4), Color(0xFFF3F4F6), Color(0xFFE5E7EB)],
        stops: [0.0, 0.45, 1.0],
      )
    : const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF2A0A0A), Color(0xFF14100F), Color(0xFF0B0A0A)],
        stops: [0.0, 0.45, 1.0],
      );

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLoginSuccess});

  final VoidCallback onLoginSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _employeeIdFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _employeeIdController.dispose();
    _passwordController.dispose();
    _employeeIdFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await AuthService.instance.login(
      employeeId: _employeeIdController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    setState(() => _loading = false);

    if (result.isSuccess) {
      widget.onLoginSuccess();
      return;
    }

    setState(() => _error = result.message);
    AppToast.showError(result.message ?? 'Login failed. Please try again.');
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: true,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: _loginBackgroundGradient),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const verticalPadding = 48.0;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 24 + bottomInset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        constraints.maxHeight - verticalPadding - bottomInset,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const BrandLogo(height: 104),
                      const SizedBox(height: 24),
                      _FeatureRow(),
                      const SizedBox(height: 28),
                      _LoginCard(
                        formKey: _formKey,
                        employeeIdController: _employeeIdController,
                        passwordController: _passwordController,
                        employeeIdFocus: _employeeIdFocus,
                        passwordFocus: _passwordFocus,
                        obscurePassword: _obscurePassword,
                        loading: _loading,
                        error: _error,
                        onTogglePassword: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        onLogin: _login,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        AppStrings.version,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _FeatureChip(icon: Icons.build_outlined, label: 'Work Orders'),
        const SizedBox(width: 8),
        _FeatureChip(icon: Icons.inventory_2_outlined, label: 'Inventory'),
        const SizedBox(width: 8),
        _FeatureChip(icon: Icons.local_shipping_outlined, label: 'Fleet'),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.14),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.gold),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.employeeIdController,
    required this.passwordController,
    required this.employeeIdFocus,
    required this.passwordFocus,
    required this.obscurePassword,
    required this.loading,
    required this.error,
    required this.onTogglePassword,
    required this.onLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController employeeIdController;
  final TextEditingController passwordController;
  final FocusNode employeeIdFocus;
  final FocusNode passwordFocus;
  final bool obscurePassword;
  final bool loading;
  final String? error;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        gradient: AppGradients.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LoginField(
              controller: employeeIdController,
              focusNode: employeeIdFocus,
              label: AppStrings.employeeId,
              hint: 'Email or username',
              icon: Icons.badge_outlined,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => passwordFocus.requestFocus(),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter your employee ID';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _LoginField(
              controller: passwordController,
              focusNode: passwordFocus,
              label: AppStrings.password,
              hint: '••••••',
              icon: Icons.lock_outline_rounded,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => onLogin(),
              suffix: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                onPressed: onTogglePassword,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Enter your password';
                }
                return null;
              },
            ),
            if (error != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.danger,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            WebPrimaryButton(
              label: AppStrings.signIn,
              loading: loading,
              onPressed: onLogin,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.textInputAction,
    this.onFieldSubmitted,
    this.suffix,
    this.validator,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffix;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.6),
            ),
            filled: true,
            fillColor: AppColors.surface,
            prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
            suffixIcon: suffix,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.danger),
            ),
          ),
        ),
      ],
    );
  }
}
