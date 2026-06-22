import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes/app_routes.dart';
import '../../l10n/l10n.dart';
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
      MaterialRequestStatus.returned => l10n.statusReturned,
      MaterialRequestStatus.declined => l10n.statusDeclined,
      MaterialRequestStatus.cancelled => l10n.statusCancelled,
      MaterialRequestStatus.superseded => l10n.statusSuperseded,
    };

/// A short context line shown in the details cell — vendor/date for accepted, the reason for
/// declined/returned. Null when there's nothing extra to say.
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
    case MaterialRequestStatus.returned:
      final reason = r.returnReason?.trim() ?? '';
      return reason.isEmpty ? null : l10n.returnedReason(reason);
    default:
      return null;
  }
}

/// Status-gated supervisor actions: cancel a `requested` item, or close / return a delivered
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
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                style: compact,
                onPressed: () => _return(context, l10n),
                child: Text(l10n.returnLabel),
              ),
              const SizedBox(width: 6),
              FilledButton.tonal(
                style: compact,
                onPressed: () => _close(context, l10n),
                child: Text(l10n.closeLabel),
              ),
            ],
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
    final ok = await _confirm(
      context,
      title: l10n.closeRequestTitle,
      body: l10n.closeRequestBody(request.particular),
      confirmLabel: l10n.closeLabel,
    );
    if (!ok) return;
    await _run(
      () => Get.find<MaterialRequestsController>().close(request.id),
      l10n.requestClosed,
    );
  }

  Future<void> _return(BuildContext context, AppLocalizations l10n) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _ReturnDialog(particular: request.particular),
    );
    if (reason == null) return;
    await _run(
      () =>
          Get.find<MaterialRequestsController>().returnItem(request.id, reason),
      l10n.requestReturned,
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

/// Return dialog — a required reason. Pops the trimmed reason, or null on cancel.
class _ReturnDialog extends StatefulWidget {
  const _ReturnDialog({required this.particular});

  final String particular;

  @override
  State<_ReturnDialog> createState() => _ReturnDialogState();
}

class _ReturnDialogState extends State<_ReturnDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_reason.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.returnRequestTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.returnRequestBody(widget.particular)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reason,
                autofocus: true,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.reasonLabel,
                  helperText: l10n.returnReasonHelper,
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a reason' : null,
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
        FilledButton(onPressed: _submit, child: Text(l10n.returnLabel)),
      ],
    );
  }
}
