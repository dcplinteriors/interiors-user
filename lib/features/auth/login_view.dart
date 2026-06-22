import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../l10n/l10n.dart';
import 'login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

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
                // Brand hero — the full DCPL logo lock-up (wordmark + tagline).
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
                          l10n.loginTitle,
                          style: theme.textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: controller.emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: InputDecoration(
                            labelText: l10n.emailLabel,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: controller.passwordController,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: l10n.passwordLabel,
                          ),
                          onSubmitted: (_) => controller.login(),
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
                        // The single molten CTA on the screen.
                        Obx(
                          () => GradientButton(
                            expand: true,
                            icon: Icons.arrow_forward_rounded,
                            loading: controller.isLoading.value,
                            label: l10n.signInButton,
                            onPressed: controller.login,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
