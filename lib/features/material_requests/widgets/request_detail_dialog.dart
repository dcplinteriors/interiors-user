import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../l10n/l10n.dart';
import '../data/data.dart';
import 'request_status_chip.dart';

/// Read-only detail for one of the supervisor's requests — the single place they can
/// review everything about an item: its number, what the admin filled in (vendor,
/// expected date, PO, remarks / decline reason), and the media they themselves
/// attached (photos, audio note) or submitted on close (bills + note). Opened by
/// tapping a row or card, so the table and card layouts expose the same picture.
///
/// The request is already fully loaded by the list, so this needs no fetch — only the
/// attachment object paths resolve to signed URLs on open (memoized + cached).
class RequestDetailDialog extends StatefulWidget {
  const RequestDetailDialog({super.key, required this.request});

  final MaterialRequest request;

  @override
  State<RequestDetailDialog> createState() => _RequestDetailDialogState();
}

class _RequestDetailDialogState extends State<RequestDetailDialog> {
  final AttachmentRepository _repo = Get.find();

  // Resolve each path to a signed URL once (memoized so rebuilds don't re-fetch).
  late final List<Future<String>> _photoUrls;
  late final List<Future<String>> _billUrls;
  Future<String>? _audioUrl;

  @override
  void initState() {
    super.initState();
    final r = widget.request;
    _photoUrls = r.attachments.photos.map(_repo.downloadUrl).toList();
    _billUrls = r.billImages.map(_repo.downloadUrl).toList();
    final audio = r.attachments.audio;
    if (audio != null) _audioUrl = _repo.downloadUrl(audio);
  }

  static String _nameWithNumber(String? name, String? number) {
    final n = name ?? 'N/A';
    return (number != null && number.isNotEmpty) ? '$n ($number)' : n;
  }

  static bool _present(String? s) => s != null && s.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final r = widget.request;

    return AlertDialog(
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(r.particular, style: theme.textTheme.headlineSmall),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              RequestStatusChip(r.status),
              const SizedBox(height: 20),

              // Identity + item.
              _Row(l10n.colItemNumber, r.itemNumber),
              _Row(l10n.colMake, r.make),
              if (r.size.isNotEmpty) _Row(l10n.colSize, r.size),
              _Row(l10n.colQty, l10n.qtyWithUnit(r.quantityLabel, r.unit)),

              const _Gap(),
              // Where it sits.
              _Row(l10n.colWorkOrder, _nameWithNumber(r.workOrderName, r.workOrderNumber)),
              _Row(l10n.colProject, _nameWithNumber(r.projectName, r.projectNumber)),
              _Row(l10n.colClient, r.clientName ?? 'N/A'),
              _Row(l10n.colSubmitted, formatDate(r.createdAt)),
              // When the materials are expected. Vendor + PO stay hidden (procurement
              // internal), but the admin's remarks ARE shown — as the decline reason on
              // a declined item, or as plain remarks otherwise.
              if (_present(r.expectedDate))
                _Row(l10n.expectedDeliveryLabel, formatDate(r.expectedDate!)),
              if (_present(r.remarks))
                _Row(
                  r.status == MaterialRequestStatus.declined
                      ? l10n.declineReasonLabel
                      : l10n.remarksLabel,
                  r.remarks!,
                ),

              // The supervisor's own attachments.
              if (_photoUrls.isNotEmpty || _audioUrl != null) ...[
                const _Gap(),
                _Section(l10n.attachments),
                if (_photoUrls.isNotEmpty) ...[
                  Text(l10n.photos, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final f in _photoUrls) _Thumb(urlFuture: f)],
                  ),
                ],
                if (_audioUrl != null) ...[
                  const SizedBox(height: 12),
                  Text(l10n.audioNote, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  AudioPlayerBar(
                    urlFuture: _audioUrl!,
                    errorLabel: l10n.couldntLoadAttachment,
                  ),
                ],
              ],

              // The supervisor's close note + bill images.
              if (_present(r.closeNote) || _billUrls.isNotEmpty) ...[
                const _Gap(),
                _Section(l10n.billsTitle),
                if (_present(r.closeNote)) ...[
                  _Row(l10n.closeNoteTitle, r.closeNote!),
                  const SizedBox(height: 8),
                ],
                if (_billUrls.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final f in _billUrls) _Thumb(urlFuture: f)],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A label/value line — label in a fixed muted column, value selectable so the
/// supervisor can copy an item/PO number.
class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _Gap extends StatelessWidget {
  const _Gap();
  @override
  Widget build(BuildContext context) => const SizedBox(height: 20);
}

/// A photo/bill thumbnail: resolves its signed URL, then shows the image (tap to
/// enlarge). Shared by the attachments and bills sections.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.urlFuture});
  final Future<String> urlFuture;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<String>(
      future: urlFuture,
      builder: (context, snap) {
        Widget child;
        if (snap.connectionState != ConnectionState.done) {
          child = const Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        } else if (snap.hasError || snap.data == null) {
          child = Icon(Icons.broken_image_outlined, color: scheme.error);
        } else {
          final url = snap.data!;
          child = InkWell(
            onTap: () => _openFull(context, url),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (ctx, w, p) => p == null
                  ? w
                  : const Center(
                      child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
              errorBuilder: (ctx, e, s) =>
                  Icon(Icons.broken_image_outlined, color: scheme.error),
            ),
          );
        }
        return Container(
          width: 116,
          height: 116,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
      },
    );
  }

  void _openFull(BuildContext context, String url) => showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
    ),
  );
}

