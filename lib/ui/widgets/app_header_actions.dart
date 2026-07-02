import 'package:flutter/material.dart';
import 'package:rapide_nforce/core/constants/app_colors.dart';
import 'package:rapide_nforce/core/constants/app_gradients.dart';
import 'package:rapide_nforce/core/constants/app_strings.dart';
import 'package:rapide_nforce/core/enums/app_route.dart';
import 'package:rapide_nforce/models/company_model.dart';
import 'package:rapide_nforce/services/auth_service.dart';
import 'package:rapide_nforce/ui/widgets/notification_bell.dart';
import 'package:rapide_nforce/ui/widgets/theme_toggle_button.dart';

class AppHeaderActions extends StatelessWidget {
  const AppHeaderActions({
    super.key,
    required this.companies,
    required this.selectedCompanyId,
    required this.loadingCompanies,
    required this.onCompanyChanged,
    this.onNavigate,
  });

  final List<CompanyModel> companies;
  final String? selectedCompanyId;
  final bool loadingCompanies;
  final ValueChanged<String> onCompanyChanged;
  final ValueChanged<AppRoute>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final hasSelection =
        selectedCompanyId != null &&
        companies.any((c) => c.id.toString() == selectedCompanyId);

    final displayRole =
        AuthService.instance.currentUser?.role ?? AppStrings.technician;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ThemeToggleButton(),
        if (loadingCompanies)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (companies.isNotEmpty)
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: hasSelection ? selectedCompanyId : null,
              hint: const Text(
                'Company',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              items: companies
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.id.toString(),
                      child: Text(c.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onCompanyChanged(v);
              },
            ),
          ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          constraints: const BoxConstraints(maxWidth: 84),
          decoration: BoxDecoration(
            gradient: AppGradients.goldAccent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            displayRole,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
            textAlign: TextAlign.center,
            softWrap: true,
          ),
        ),
        NotificationBell(reloadKey: selectedCompanyId, onNavigate: onNavigate),
      ],
    );
  }
}
