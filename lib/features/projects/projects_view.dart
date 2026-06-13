import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes/app_routes.dart';
import '../../l10n/l10n.dart';
import 'projects_controller.dart';

class ProjectsView extends GetView<ProjectsController> {
  const ProjectsView({super.key});

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
                        l10n.projectsTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Obx(
                      () => Text(
                        l10n.countProjects(controller.projects.length),
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
              Obx(
                () => RefreshButton(
                  tooltip: l10n.refresh,
                  onPressed: controller.fetch,
                  isRefreshing: controller.isLoading.value && controller.projects.isNotEmpty,
                ),
              ),
            ],
          ),
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
            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : OutlinedButton.icon(onPressed: controller.loadMore, icon: const Icon(Icons.expand_more), label: Text(l10n.loadMore)),
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n) {
    if (controller.isLoading.value && controller.projects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.error.value != null) {
      return ErrorState(title: l10n.couldntLoadProjects, message: controller.error.value!, retryLabel: l10n.retry, onRetry: controller.fetch);
    }
    if (controller.projects.isEmpty) {
      return EmptyState(icon: Icons.folder_off_outlined, title: l10n.noProjectsTitle, body: l10n.noProjectsBody);
    }
    return context.isCompact ? _cards(context, l10n) : _table(context, l10n);
  }

  Widget _cards(BuildContext context, AppLocalizations l10n) => ListView.separated(
    padding: EdgeInsets.zero,
    itemCount: controller.projects.length,
    separatorBuilder: (_, _) => const SizedBox(height: 12),
    itemBuilder: (context, i) {
      final p = controller.projects[i];
      return EntityCard(
        title: p.particular,
        trailing: _ProjectStatus(p.status),
        fields: [
          EntityField(l10n.colClient, text: p.clientName),
          EntityField(l10n.colPo, text: p.po, muted: true),
          EntityField(l10n.colDate, text: formatDate(p.date)),
        ],
        footer: FilledButton.tonalIcon(
          onPressed: () => context.push('${AppRoutes.newRequest}?projectId=${p.id}'),
          icon: const Icon(Icons.add, size: 18),
          label: Text(l10n.requestMaterial),
        ),
      );
    },
  );

  Widget _table(BuildContext context, AppLocalizations l10n) {
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
              DataColumn(label: Text(l10n.colProject)),
              DataColumn(label: Text(l10n.colClient)),
              DataColumn(label: Text(l10n.colPo)),
              DataColumn(label: Text(l10n.colDate)),
              DataColumn(label: Text(l10n.colStatus)),
              const DataColumn(label: Text('')),
            ],
            rows: [
              for (final p in controller.projects)
                DataRow(
                  cells: [
                    DataCell(Text(p.particular, style: const TextStyle(fontWeight: FontWeight.w500))),
                    DataCell(Text(p.clientName)),
                    DataCell(Text(p.po, style: TextStyle(color: muted))),
                    DataCell(Text(formatDate(p.date))),
                    DataCell(_ProjectStatus(p.status)),
                    DataCell(
                      FilledButton.tonalIcon(
                        onPressed: () => context.push('${AppRoutes.newRequest}?projectId=${p.id}'),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(l10n.requestMaterial),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectStatus extends StatelessWidget {
  const _ProjectStatus(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active = status == 'active';
    final colors = context.statusColors.forProject(status);
    return Chip(
      avatar: Icon(active ? Icons.bolt : Icons.check_circle_outline, size: 16, color: colors.ink),
      label: Text(active ? l10n.statusActive : l10n.statusCompleted, style: TextStyle(color: colors.ink)),
      backgroundColor: colors.surface,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
