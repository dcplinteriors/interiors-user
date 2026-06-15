import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes/app_routes.dart';
import '../../l10n/l10n.dart';
import '../projects/projects_controller.dart';
import 'material_requests_controller.dart';
import 'widgets/request_status_chip.dart';

class RequestsView extends GetView<MaterialRequestsController> {
  const RequestsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final projects = Get.find<ProjectsController>();
    return Padding(
      padding: context.pagePadding,
      child: Obx(() {
        // A request is always raised against an assigned project. With none
        // assigned, the office hasn't onboarded this supervisor yet — block
        // creating requests and explain why, rather than leading to a dead end.
        final blocked = !projects.isLoading.value &&
            projects.error.value == null &&
            projects.projects.isEmpty;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: l10n.requestsTitle,
              count: '${controller.requests.length}',
              actions: [
                RefreshButton(
                  tooltip: l10n.refresh,
                  onPressed: controller.fetch,
                  isRefreshing:
                      controller.isLoading.value && controller.requests.isNotEmpty,
                ),
                if (!blocked) _newRequestAction(context, l10n),
              ],
            ),
            const SizedBox(height: 20),
            if (blocked)
              Expanded(
                child: EmptyState(
                  icon: Icons.assignment_late_outlined,
                  title: l10n.requestsBlockedTitle,
                  body: l10n.requestsBlockedBody,
                ),
              )
            else ...[
              _filter(l10n),
              const SizedBox(height: 16),
              Expanded(child: _body(context, l10n)),
              _loadMoreBar(l10n),
            ],
          ],
        );
      }),
    );
  }

  // Primary action: a full molten button on wide layouts, a compact "+" on phones.
  Widget _newRequestAction(BuildContext context, AppLocalizations l10n) =>
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
            );

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
      // softWrap:false so each segment sizes to its full label — in the
      // unbounded scroll view SegmentedButton would otherwise collapse segments
      // to their longest word and wrap the labels.
      segments: [
        ButtonSegment(value: null, label: Text(l10n.segAll, softWrap: false, maxLines: 1)),
        ButtonSegment(value: 'requested', label: Text(l10n.segRequested, softWrap: false, maxLines: 1)),
        ButtonSegment(value: 'accepted', label: Text(l10n.segAccepted, softWrap: false, maxLines: 1)),
        ButtonSegment(value: 'declined', label: Text(l10n.segDeclined, softWrap: false, maxLines: 1)),
        ButtonSegment(value: 'cancelled', label: Text(l10n.segCancelled, softWrap: false, maxLines: 1)),
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

  // The make + size context line under an item title.
  String _itemSubtitle(MaterialRequest r) =>
      [r.make, r.size].where((s) => s.isNotEmpty).join(' · ');

  Widget _cards(BuildContext context, AppLocalizations l10n, List<MaterialRequest> rows) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final status = context.statusColors;
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final r = rows[i];
        return EntityCard(
          eyebrow: l10n.colItem,
          railColor: status.forRequest(r.status).ink,
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
    final status = context.statusColors;
    return DcplTable(
      columns: [
        DcplColumn(l10n.colItem, flex: 3),
        DcplColumn(l10n.colProject, flex: 2),
        DcplColumn(l10n.colQty, fixedWidth: 100),
        DcplColumn(l10n.colJobNo, fixedWidth: 110),
        DcplColumn(l10n.colSubmitted, fixedWidth: 96, numeric: true),
        DcplColumn(l10n.colStatus, fixedWidth: 168),
        DcplColumn(l10n.colDetails, fixedWidth: 200),
      ],
      rows: [
        for (final r in rows)
          DcplRow(
            railColor: status.forRequest(r.status).ink,
            cells: [
              PrimaryCell(r.particular, subtitle: _itemSubtitle(r)),
              Text(r.projectName ?? '—'),
              Text(l10n.qtyWithUnit(r.quantityLabel, r.unit)),
              Text(r.jobNumber, style: TextStyle(color: muted)),
              Text(formatDate(r.createdAt)),
              RequestStatusChip(r.status),
              _action(context, l10n, r, muted),
            ],
          ),
      ],
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

