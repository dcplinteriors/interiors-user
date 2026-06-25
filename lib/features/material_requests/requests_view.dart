import 'dart:typed_data';

import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/routes/app_routes.dart';
import '../../l10n/l10n.dart';
import 'data/upload_service.dart';
import 'material_requests_controller.dart';
import 'widgets/request_status_chip.dart';

class RequestsView extends GetView<MaterialRequestsController> {
  const RequestsView({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: context.pagePadding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Header(),
        const SizedBox(height: 20),
        const _Filters(),
        const SizedBox(height: 16),
        const Expanded(child: _Body()),
        LoadMoreBar(
          controller: controller,
          label: AppLocalizations.of(context).loadMore,
        ),
      ],
    ),
  );
}

class _Header extends GetView<MaterialRequestsController> {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Obx(() {
      // No assignable work order ⇒ nothing to request against: hide the entry point.
      final canCreate = controller.hasAssignableWorkOrder.value;
      return PageHeader(
        title: l10n.requestsTitle,
        count: '${controller.requests.length}',
        actions: [
          RefreshButton(
            tooltip: l10n.refresh,
            onPressed: controller.fetch,
            isRefreshing:
                controller.isLoading.value && controller.requests.isNotEmpty,
          ),
          if (canCreate)
            context.isCompact
                ? IconButton.filled(
                    tooltip: l10n.newRequest,
                    onPressed: () => context.push(AppRoutes.newRequest),
                    icon: const Icon(Icons.add),
                  )
                : GradientButton(
                    onPressed: () => context.push(AppRoutes.newRequest),
                    icon: Icons.add,
                    label: l10n.newRequest,
                  ),
        ],
      );
    });
  }
}

class _Filters extends GetView<MaterialRequestsController> {
  const _Filters();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Obx(
      () => Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilterDropdown<MaterialRequestStatus?>(
            value: controller.statusFilter.value,
            onChanged: controller.setStatusFilter,
            options: [
              FilterOption(null, l10n.allStatuses),
              for (final s in MaterialRequestStatus.values)
                FilterOption(s, _statusLabel(l10n, s)),
            ],
          ),
          // Flat work-order filter over all the supervisor's work orders.
          if (controller.workOrders.isNotEmpty)
            FilterDropdown<String?>(
              value: controller.workOrderFilter.value,
              onChanged: controller.setWorkOrderFilter,
              options: [
                FilterOption(null, l10n.allWorkOrders),
                for (final w in controller.workOrders)
                  FilterOption(w.id, w.name),
              ],
            ),
        ],
      ),
    );
  }
}

class _Body extends GetView<MaterialRequestsController> {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Obx(() {
      if (controller.isLoading.value && controller.requests.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.error.value != null) {
        return ErrorState(
          title: l10n.couldntLoadRequests,
          message: controller.error.value!,
          retryLabel: l10n.retry,
          onRetry: controller.fetch,
        );
      }
      if (controller.requests.isEmpty) {
        if (controller.statusFilter.value != null) {
          return EmptyState(
            icon: Icons.filter_alt_off_outlined,
            title: l10n.nothingHereTitle,
            body: l10n.nothingHereBody,
          );
        }
        // Nothing assigned ⇒ explain why, and offer no "create" action.
        if (!controller.hasAssignableWorkOrder.value) {
          return EmptyState(
            icon: Icons.assignment_late_outlined,
            title: l10n.noAssignedWorkOrdersTitle,
            body: l10n.noWorkOrdersAssigned,
          );
        }
        return EmptyState(
          icon: Icons.inventory_2_outlined,
          title: l10n.noRequestsTitle,
          body: l10n.noRequestsBody,
          action: FilledButton.icon(
            onPressed: () => context.push(AppRoutes.newRequest),
            icon: const Icon(Icons.add),
            label: Text(l10n.newRequest),
          ),
        );
      }
      final rows = controller.requests.toList();
      return context.isCompact ? _Cards(rows) : _Table(rows);
    });
  }
}

class _Cards extends StatelessWidget {
  const _Cards(this.requests);

  final List<MaterialRequest> requests;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = context.statusColors;
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: requests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final r = requests[i];
        return EntityCard(
          eyebrow: l10n.colItem,
          railColor: status.forRequest(r.status.wire).ink,
          title: r.particular,
          trailing: RequestStatusChip(r.status),
          fields: [
            EntityField(l10n.colMake, text: r.make, muted: true),
            if (r.size.isNotEmpty) EntityField(l10n.colSize, text: r.size),
            EntityField(
              l10n.colQty,
              text: l10n.qtyWithUnit(r.quantityLabel, r.unit),
            ),
            EntityField(l10n.navWorkOrders, text: r.workOrderName ?? '—'),
            EntityField(l10n.colSubmitted, text: formatDate(r.createdAt)),
            if (_detail(l10n, r) case final d?)
              EntityField(l10n.colDetails, text: d, muted: true),
          ],
          footer: _RowActions(r),
        );
      },
    );
  }
}

class _Table extends StatelessWidget {
  const _Table(this.requests);

  final List<MaterialRequest> requests;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = context.statusColors;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return DcplTable(
      columns: [
        DcplColumn(l10n.colItem, flex: 3),
        DcplColumn(l10n.navWorkOrders, flex: 2),
        DcplColumn(l10n.colQty, fixedWidth: 100),
        DcplColumn(l10n.colSubmitted, fixedWidth: 96, numeric: true),
        DcplColumn(l10n.colStatus, fixedWidth: 168),
        DcplColumn(l10n.colDetails, fixedWidth: 220),
      ],
      rows: [
        for (final r in requests)
          DcplRow(
            railColor: status.forRequest(r.status.wire).ink,
            cells: [
              PrimaryCell(
                r.particular,
                subtitle: [
                  r.make,
                  r.size,
                ].where((s) => s.isNotEmpty).join(' · '),
              ),
              Text(r.workOrderName ?? '—'),
              Text(l10n.qtyWithUnit(r.quantityLabel, r.unit)),
              Text(formatDate(r.createdAt)),
              RequestStatusChip(r.status),
              _RowActions(r, muted: muted),
            ],
          ),
      ],
    );
  }
}

String _statusLabel(AppLocalizations l10n, MaterialRequestStatus s) =>
    switch (s) {
      MaterialRequestStatus.requested => l10n.statusRequested,
      MaterialRequestStatus.processing => l10n.statusProcessing,
      MaterialRequestStatus.accepted => l10n.statusAccepted,
      MaterialRequestStatus.closed => l10n.statusClosed,
      MaterialRequestStatus.declined => l10n.statusDeclined,
      MaterialRequestStatus.cancelled => l10n.statusCancelled,
    };

/// A short context line shown in the details cell — vendor/date for accepted, the reason for
/// declined. Null when there's nothing extra to say.
String? _detail(AppLocalizations l10n, MaterialRequest r) {
  switch (r.status) {
    case MaterialRequestStatus.accepted:
      final vendor = r.vendor?.trim() ?? '';
      final date = r.expectedDate != null ? formatDate(r.expectedDate!) : '';
      if (vendor.isEmpty && date.isEmpty) return null;
      return [
        if (vendor.isNotEmpty) vendor,
        if (date.isNotEmpty) l10n.expectedOn(date),
      ].join(' · ');
    case MaterialRequestStatus.declined:
      final reason = r.remarks?.trim() ?? '';
      return reason.isEmpty ? null : l10n.declinedReason(reason);
    default:
      return null;
  }
}

/// Status-gated supervisor actions: cancel a `requested` item, or close a delivered
/// (`accepted`) one. Other statuses are terminal — the details cell already explains them.
class _RowActions extends StatelessWidget {
  const _RowActions(this.request, {this.muted});

  final MaterialRequest request;
  final Color? muted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const compact = ButtonStyle(
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    switch (request.status) {
      case MaterialRequestStatus.requested:
        return Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            style: compact,
            onPressed: () => _cancel(context, l10n),
            child: Text(l10n.cancel),
          ),
        );
      case MaterialRequestStatus.accepted:
        return Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
            style: compact,
            onPressed: () => _close(context, l10n),
            child: Text(l10n.closeLabel),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _cancel(BuildContext context, AppLocalizations l10n) async {
    final ok = await _confirm(
      context,
      title: l10n.cancelRequestTitle,
      body: l10n.cancelRequestBody(request.particular),
      confirmLabel: l10n.cancelRequestConfirm,
      destructive: true,
    );
    if (!ok) return;
    await _run(
      () => Get.find<MaterialRequestsController>().cancel(request.id),
      l10n.requestCancelled,
    );
  }

  Future<void> _close(BuildContext context, AppLocalizations l10n) async {
    final result = await showDialog<_CloseResult>(
      context: context,
      builder: (_) => _CloseDialog(particular: request.particular),
    );
    if (result == null) return;
    await _run(
      () => Get.find<MaterialRequestsController>().close(
        request.id,
        billImages: result.billImages,
        note: result.note,
      ),
      l10n.requestClosed,
    );
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.keepLabel),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  )
                : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _run(
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      showAppSnackbar(successMessage);
    } on ApiException catch (e) {
      showAppSnackbar(e.message);
    } catch (_) {
      showAppSnackbar('Something went wrong. Please try again.');
    }
  }
}

/// What the close dialog returns: the uploaded bill-image paths + an optional note.
class _CloseResult {
  _CloseResult(this.billImages, this.note);
  final List<String> billImages;
  final String? note;
}

/// A bill image being uploaded: preview bytes + outcome. `path` is set on success;
/// `failed` flags a retryable failure.
class _BillUpload {
  _BillUpload({required this.bytes, required this.contentType});
  final Uint8List bytes;
  final String contentType;
  String? path;
  bool failed = false;

  bool get uploading => path == null && !failed;
}

/// Close dialog — at least one bill image is required (up to [kMaxBillImages]), plus an
/// optional note. Pops a [_CloseResult], or null on cancel.
class _CloseDialog extends StatefulWidget {
  const _CloseDialog({required this.particular});

  final String particular;

  @override
  State<_CloseDialog> createState() => _CloseDialogState();
}

class _CloseDialogState extends State<_CloseDialog> {
  late final UploadService _uploads = Get.find();
  final ImagePicker _picker = ImagePicker();
  final _note = TextEditingController();
  final List<_BillUpload> _bills = [];

  bool get _busy => _bills.any((b) => b.uploading);
  bool get _hasFailed => _bills.any((b) => b.failed);
  List<String> get _paths => [
    for (final b in _bills)
      if (b.path != null) b.path!,
  ];
  bool get _canSubmit => _paths.isNotEmpty && !_busy && !_hasFailed;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _add(ImageSource source) async {
    final l10n = AppLocalizations.of(context);
    if (_bills.length >= kMaxBillImages) return;
    final _BillUpload up;
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 2400);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      up = _BillUpload(
        bytes: bytes,
        contentType: photoContentType(
          bytes,
          mimeType: file.mimeType,
          fileName: file.name,
        ),
      );
    } catch (_) {
      showAppSnackbar(l10n.photoPickFailed);
      return;
    }
    setState(() => _bills.add(up));
    await _upload(up);
  }

  Future<void> _upload(_BillUpload up) async {
    setState(() {
      up.failed = false;
      up.path = null;
    });
    try {
      up.path = await _uploads.upload(
        kind: AttachmentKind.photo,
        bytes: up.bytes,
        contentType: up.contentType,
      );
    } catch (_) {
      up.failed = true;
    }
    if (mounted) setState(() {});
  }

  void _remove(_BillUpload up) => setState(() => _bills.remove(up));

  void _submit() {
    if (!_canSubmit) return;
    final note = _note.text.trim();
    Navigator.of(context).pop(_CloseResult(_paths, note.isEmpty ? null : note));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final atMax = _bills.length >= kMaxBillImages;
    return AlertDialog(
      title: Text(l10n.closeRequestTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.closeRequestBody(widget.particular)),
              const SizedBox(height: 16),
              Text(
                '${l10n.closeBillsLabel} · ${_bills.length}/$kMaxBillImages',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 2),
              Text(
                l10n.closeBillsHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final b in _bills)
                    _BillThumb(
                      upload: b,
                      onRemove: () => _remove(b),
                      onRetry: () => _upload(b),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: atMax ? null : () => _add(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_outlined, size: 18),
                    label: Text(l10n.takePhoto),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: atMax ? null : () => _add(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(l10n.addPhoto),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _note,
                maxLines: 3,
                decoration: InputDecoration(labelText: l10n.closeNoteLabel),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: Text(l10n.closeLabel),
        ),
      ],
    );
  }
}

/// One bill thumbnail with upload state (spinner / failed→retry) and a remove badge.
class _BillThumb extends StatelessWidget {
  const _BillThumb({
    required this.upload,
    required this.onRemove,
    required this.onRetry,
  });

  final _BillUpload upload;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 76,
    height: 76,
    child: Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(upload.bytes, fit: BoxFit.cover),
        ),
        if (upload.uploading)
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        if (upload.failed)
          Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(8),
              child: const Center(
                child: Icon(Icons.refresh, color: Colors.white, size: 22),
              ),
            ),
          ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: const CircleAvatar(
              radius: 11,
              backgroundColor: Colors.black87,
              child: Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}
