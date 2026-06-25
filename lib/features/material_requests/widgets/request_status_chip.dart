import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

/// A coloured chip for the material-request statuses. Colours come from the shared
/// semantic palette ([StatusColors]); only icon + label are decided here.
class RequestStatusChip extends StatelessWidget {
  const RequestStatusChip(this.status, {super.key});

  final MaterialRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.statusColors.forRequest(status.wire);

    final (IconData icon, String label) = switch (status) {
      MaterialRequestStatus.requested => (
        Icons.inbox_outlined,
        l10n.statusRequested,
      ),
      MaterialRequestStatus.processing => (
        Icons.hourglass_top,
        l10n.statusProcessing,
      ),
      MaterialRequestStatus.accepted => (
        Icons.local_shipping_outlined,
        l10n.statusAccepted,
      ),
      MaterialRequestStatus.closed => (
        Icons.check_circle_outline,
        l10n.statusClosed,
      ),
      MaterialRequestStatus.declined => (
        Icons.cancel_outlined,
        l10n.statusDeclined,
      ),
      MaterialRequestStatus.cancelled => (
        Icons.block_outlined,
        l10n.statusCancelled,
      ),
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
