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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Title + count share a flexible slot so the title can ellipsize
              // on narrow widths; the actions then sit flush-right (no Spacer to
              // fight over slack, so no stray gap).
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        l10n.requestsTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Obx(() => Text(
                          l10n.countRequests(controller.requests.length),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        )),
                  ],
                ),
              ),
              Obx(() => RefreshButton(
                    tooltip: l10n.refresh,
                    onPressed: controller.fetch,
                    isRefreshing:
                        controller.isLoading.value && controller.requests.isNotEmpty,
                  )),
              const SizedBox(width: 4),
              // On phones the FAB-style "+" is enough; the label needs room.
              if (context.isCompact)
                IconButton.filled(
                  tooltip: l10n.newRequest,
                  onPressed: () => context.push(AppRoutes.newRequest),
                  icon: const Icon(Icons.add),
                )
              else
                FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.newRequest),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.newRequest),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Obx(() => _filter(l10n)),
          const SizedBox(height: 16),
          Expanded(child: Obx(() => _body(context, l10n))),
          Obx(() => _loadMoreBar(l10n)),
        ],
      ),
    );
  }

  Widget _loadMoreBar(AppLocalizations l10n) {
    if (!controller.hasMore) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: controller.isLoadingMore.value
            ? const SizedBox(
                height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : OutlinedButton.icon(
                onPressed: controller.loadMore,
                icon: const Icon(Icons.expand_more),
                label: Text(l10n.loadMore),
              ),
      ),
    );
  }

  Widget _filter(AppLocalizations l10n) {
    final button = SegmentedButton<String?>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: null, label: Text(l10n.segAll)),
        ButtonSegment(value: 'requested', label: Text(l10n.segRequested)),
        ButtonSegment(value: 'accepted', label: Text(l10n.segAccepted)),
        ButtonSegment(value: 'declined', label: Text(l10n.segDeclined)),
        ButtonSegment(value: 'cancelled', label: Text(l10n.segCancelled)),
      ],
      selected: {controller.statusFilter.value},
      onSelectionChanged: (s) => controller.setFilter(s.first),
    );
    // Five segments overflow a phone; let them scroll horizontally there.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: button,
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n) {
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
    final rows = controller.requests;
    if (rows.isEmpty) {
      // No rows at all → invite; a filter with no matches → neutral.
      if (controller.statusFilter.value == null) {
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
      return EmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: l10n.nothingHereTitle,
        body: l10n.nothingHereBody,
      );
    }
    return context.isCompact
        ? _cards(context, l10n, rows)
        : _table(context, l10n, rows);
  }

  Widget _cards(BuildContext context, AppLocalizations l10n, List<MaterialRequest> rows) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final r = rows[i];
        return EntityCard(
          title: r.particular,
          trailing: RequestStatusChip(r.status),
          fields: [
            EntityField(l10n.colMake, text: r.make, muted: true),
            if (r.size.isNotEmpty) EntityField(l10n.colSize, text: r.size),
            EntityField(l10n.colProject, text: r.projectName ?? '—'),
            EntityField(l10n.colQty, text: l10n.qtyWithUnit(r.quantityLabel, r.unit)),
            EntityField(l10n.colJobNo, text: r.jobNumber, muted: true),
            EntityField(l10n.colSubmitted, text: formatDate(r.createdAt)),
          ],
          footer: _action(context, l10n, r, muted),
        );
      },
    );
  }

  Widget _table(BuildContext context, AppLocalizations l10n, List<MaterialRequest> rows) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) => ScrollableTable(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: DataTable(
            columnSpacing: 24,
            columns: [
              DataColumn(label: Text(l10n.colItem)),
              DataColumn(label: Text(l10n.colMake)),
              DataColumn(label: Text(l10n.colSize)),
              DataColumn(label: Text(l10n.colProject)),
              DataColumn(label: Text(l10n.colQty)),
              DataColumn(label: Text(l10n.colJobNo)),
              DataColumn(label: Text(l10n.colStatus)),
              DataColumn(label: Text(l10n.colSubmitted)),
              DataColumn(label: Text(l10n.colDetails)),
            ],
            rows: [
              for (final r in rows)
                DataRow(
                  cells: [
                    DataCell(Text(r.particular,
                        style: const TextStyle(fontWeight: FontWeight.w500))),
                    DataCell(Text(r.make, style: TextStyle(color: muted))),
                    DataCell(Text(r.size.isEmpty ? '—' : r.size)),
                    DataCell(Text(r.projectName ?? '—')),
                    DataCell(Text(l10n.qtyWithUnit(r.quantityLabel, r.unit))),
                    DataCell(Text(r.jobNumber, style: TextStyle(color: muted))),
                    DataCell(RequestStatusChip(r.status)),
                    DataCell(Text(formatDate(r.createdAt))),
                    DataCell(_action(context, l10n, r, muted)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(BuildContext context, AppLocalizations l10n, MaterialRequest r, Color muted) {
    switch (r.status) {
      case 'requested':
        return TextButton(
          onPressed: () => _confirmCancel(context, l10n, r),
          child: Text(l10n.cancel),
        );
      case 'accepted':
        final date = r.expectedDate != null ? formatDate(r.expectedDate!) : '';
        return Text(l10n.acceptedInfo(date), style: TextStyle(color: muted));
      case 'declined':
        final reason = r.remarks?.trim() ?? '';
        if (reason.isEmpty) {
          return Text(l10n.declinedShort, style: TextStyle(color: muted));
        }
        return Tooltip(
          message: reason,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              l10n.declinedReason(reason),
              style: TextStyle(color: muted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      default:
        return Text(l10n.withdrawnShort, style: TextStyle(color: muted));
    }
  }

  Future<void> _confirmCancel(
    BuildContext context,
    AppLocalizations l10n,
    MaterialRequest r,
  ) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.cancelRequestTitle),
        content: Text(l10n.cancelRequestBody(r.particular)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.keepLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.cancelRequestConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await controller.cancel(r.id);
      showAppSnackbar(l10n.requestCancelled);
    } on ApiException catch (e) {
      showAppSnackbar(e.message);
    } catch (_) {
      showAppSnackbar('Something went wrong. Please try again.');
    }
  }
}

