import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes/app_routes.dart';
import '../../l10n/l10n.dart';
import 'widgets/work_order_status_chip.dart';
import 'work_orders_controller.dart';

class WorkOrdersView extends GetView<WorkOrdersController> {
  const WorkOrdersView({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: context.pagePadding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Header(),
        const SizedBox(height: 20),
        const _Filter(),
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

class _Header extends GetView<WorkOrdersController> {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Obx(
      () => PageHeader(
        title: l10n.workOrdersTitle,
        count: '${controller.workOrders.length}',
        actions: [
          RefreshButton(
            tooltip: l10n.refresh,
            onPressed: controller.fetch,
            isRefreshing:
                controller.isLoading.value && controller.workOrders.isNotEmpty,
          ),
        ],
      ),
    );
  }
}

class _Filter extends GetView<WorkOrdersController> {
  const _Filter();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Obx(() {
      // Only worth showing once the supervisor spans more than one project.
      if (controller.projects.length < 2) return const SizedBox.shrink();
      return Align(
        alignment: Alignment.centerLeft,
        child: FilterDropdown<String?>(
          value: controller.projectFilter.value,
          onChanged: controller.setProjectFilter,
          options: [
            FilterOption(null, l10n.allProjects),
            for (final p in controller.projects) FilterOption(p.id, p.name),
          ],
        ),
      );
    });
  }
}

class _Body extends GetView<WorkOrdersController> {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Obx(() {
      if (controller.isLoading.value && controller.workOrders.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.error.value != null) {
        return ErrorState(
          title: l10n.couldntLoadWorkOrders,
          message: controller.error.value!,
          retryLabel: l10n.retry,
          onRetry: controller.fetch,
        );
      }
      if (controller.workOrders.isEmpty) {
        return EmptyState(
          icon: Icons.assignment_outlined,
          title: l10n.noWorkOrdersTitle,
          body: l10n.noWorkOrdersBody,
        );
      }
      final rows = controller.workOrders.toList();
      return context.isCompact ? _Cards(rows) : _Table(rows);
    });
  }
}

void _requestMaterial(BuildContext context, String workOrderId) =>
    context.push('${AppRoutes.newRequest}?workOrderId=$workOrderId');

class _Cards extends StatelessWidget {
  const _Cards(this.workOrders);

  final List<WorkOrder> workOrders;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = context.statusColors;
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: workOrders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final w = workOrders[i];
        return EntityCard(
          eyebrow: l10n.navWorkOrders,
          railColor: status.forWorkOrder(w.status.wire).ink,
          title: w.name,
          trailing: WorkOrderStatusChip(w.status),
          fields: [
            EntityField(l10n.colNumber, text: w.number, muted: true),
            EntityField(l10n.colProject, text: w.projectName ?? '—'),
            EntityField(l10n.colClient, text: w.clientName ?? '—'),
            EntityField(l10n.colDate, text: formatDate(w.date)),
          ],
          footer: w.status == WorkOrderStatus.active
              ? SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _requestMaterial(context, w.id),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n.requestMaterial),
                  ),
                )
              : null,
        );
      },
    );
  }
}

class _Table extends StatelessWidget {
  const _Table(this.workOrders);

  final List<WorkOrder> workOrders;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = context.statusColors;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return DcplTable(
      columns: [
        DcplColumn(l10n.navWorkOrders, flex: 3),
        DcplColumn(l10n.colProject, flex: 2),
        DcplColumn(l10n.colClient, flex: 2),
        DcplColumn(l10n.colDate, fixedWidth: 96, numeric: true),
        DcplColumn(l10n.colStatus, fixedWidth: 150),
        const DcplColumn('', fixedWidth: 190),
      ],
      rows: [
        for (final w in workOrders)
          DcplRow(
            railColor: status.forWorkOrder(w.status.wire).ink,
            cells: [
              PrimaryCell(w.name, subtitle: w.number),
              Text(w.projectName ?? '—'),
              Text(w.clientName ?? '—', style: TextStyle(color: muted)),
              Text(formatDate(w.date)),
              WorkOrderStatusChip(w.status),
              if (w.status == WorkOrderStatus.active)
                FilledButton.tonalIcon(
                  onPressed: () => _requestMaterial(context, w.id),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.requestMaterial),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
      ],
    );
  }
}
