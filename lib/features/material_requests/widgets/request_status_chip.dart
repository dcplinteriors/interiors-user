import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

/// A coloured chip for the four material-request statuses (supervisor view).
/// Colours come from the shared semantic palette ([StatusColors]); only the
/// icon + localized label are decided here.
class RequestStatusChip extends StatelessWidget {
  const RequestStatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.statusColors.forRequest(status);

    final (IconData icon, String label) = switch (status) {
      'requested' => (Icons.inbox_outlined, l10n.statusRequested),
      'accepted' => (Icons.check_circle_outline, l10n.statusAccepted),
      'declined' => (Icons.cancel_outlined, l10n.statusDeclined),
      _ => (Icons.block_outlined, l10n.statusCancelled),
    };

    return Chip(
      avatar: Icon(icon, size: 16, color: colors.ink),
      label: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: TextStyle(color: colors.ink),
      ),
      backgroundColor: colors.surface,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
