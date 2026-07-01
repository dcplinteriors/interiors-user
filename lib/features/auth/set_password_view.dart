import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../l10n/l10n.dart';
import 'set_password_controller.dart';

/// Blocking first-login screen: a supervisor on a temporary password must set
/// their own before they can reach the rest of the app. Navigation away is
/// driven by the router once the session gate clears.
class SetPasswordView extends GetView<SetPasswordController> {
  const SetPasswordView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: BrandWordmark(height: 84, tagline: true)),
                const SizedBox(height: 36),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.setPasswordTitle,
                          style: theme.textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.setPasswordSubtitle,
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: controller.passwordController,
                          obscureText: true,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText: l10n.newPasswordLabel,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: controller.confirmController,
                          obscureText: true,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText: l10n.confirmPasswordLabel,
                          ),
                          onSubmitted: (_) => controller.submit(),
                        ),
                        Obx(() {
                          final error = controller.error.value;
                          if (error == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              error,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                        Obx(
                          () => GradientButton(
                            expand: true,
                            icon: Icons.arrow_forward_rounded,
                            loading: controller.isLoading.value,
                            label: l10n.setPasswordButton,
                            onPressed: controller.submit,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Escape hatch: if Firebase demands a fresh sign-in
                // (`requires-recent-login`), let the user get back to login.
                TextButton(
                  onPressed: Get.find<AuthService>().signOut,
                  child: Text(l10n.signOut),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
