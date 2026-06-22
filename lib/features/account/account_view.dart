import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/l10n.dart';
import '../material_requests/data/upload_service.dart';
import 'account_controller.dart';

class AccountView extends GetView<AccountController> {
  const AccountView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: context.pagePadding,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Obx(() {
            if (controller.isLoading.value && controller.user.value == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.error.value != null &&
                controller.user.value == null) {
              return ErrorState(
                title: l10n.couldntLoadProfile,
                message: controller.error.value!,
                retryLabel: l10n.retry,
                onRetry: controller.load,
              );
            }
            final user = controller.user.value;
            if (user == null) return const SizedBox.shrink();
            return ListView(
              children: [
                const SizedBox(height: 8),
                Center(child: _Avatar(name: user.name)),
                const SizedBox(height: 24),
                _NameTile(name: user.name),
                const SizedBox(height: 12),
                _ReadOnlyTile(label: l10n.emailLabel, value: user.email ?? '—'),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: Get.find<AuthService>().signOut,
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.signOut),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// The profile avatar with a camera edit badge; shows a spinner while a new photo uploads.
class _Avatar extends GetView<AccountController> {
  const _Avatar({required this.name});

  final String name;

  Future<void> _pickPhoto(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await controller.updatePhoto(
        bytes,
        photoContentType(bytes, mimeType: file.mimeType, fileName: file.name),
      );
    } on ApiException catch (e) {
      showAppSnackbar(e.message);
    } catch (_) {
      showAppSnackbar(l10n.photoPickFailed);
    }
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final url = controller.photoUrl.value;
    return Stack(
      alignment: Alignment.center,
      children: [
        ProfileAvatar(
          initials: _initials(name),
          image: url == null ? null : NetworkImage(url),
          onEdit: controller.photoUploading.value
              ? null
              : () => _pickPhoto(context),
        ),
        if (controller.photoUploading.value)
          const SizedBox(
            height: 28,
            width: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  });
}

class _NameTile extends GetView<AccountController> {
  const _NameTile({required this.name});

  final String name;

  Future<void> _edit(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(initial: name),
    );
    if (newName == null || newName == name) return;
    try {
      await controller.updateName(newName);
      showAppSnackbar(l10n.nameUpdated);
    } on ApiException catch (e) {
      showAppSnackbar(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _edit(context),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.nameLabel,
          suffixIcon: const Icon(Icons.edit_outlined, size: 18),
        ),
        child: Text(
          name.isEmpty ? l10n.addYourName : name,
          style: name.isEmpty
              ? TextStyle(color: scheme.onSurfaceVariant)
              : null,
        ),
      ),
    );
  }
}

class _ReadOnlyTile extends StatelessWidget {
  const _ReadOnlyTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => InputDecorator(
    decoration: InputDecoration(labelText: label),
    child: Text(value),
  );
}

/// Edit-name dialog — pops the trimmed name, or null on cancel.
class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initial});

  final String initial;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.editNameTitle),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: l10n.nameLabel),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
