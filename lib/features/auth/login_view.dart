import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../l10n/l10n.dart';
import 'login_controller.dart';

class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.loginTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: controller.emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: InputDecoration(labelText: l10n.emailLabel),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller.passwordController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(labelText: l10n.passwordLabel),
                      onSubmitted: (_) => controller.login(),
                    ),
                    const SizedBox(height: 8),
                    Obx(() {
                      final error = controller.error.value;
                      if (error == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          error,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Obx(() => FilledButton(
                          onPressed: controller.isLoading.value ? null : controller.login,
                          child: controller.isLoading.value
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(l10n.signInButton),
                        )),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
