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
          Obx(() => PageHeader(
                title: l10n.projectsTitle,
                count: '${controller.projects.length}',
                actions: [
                  Obx(() => RefreshButton(
                        tooltip: l10n.refresh,
                        onPressed: controller.fetch,
                        isRefreshing: controller.isLoading.value &&
                            controller.projects.isNotEmpty,
                      )),
                ],
              )),
          const SizedBox(height: 24),
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

  Widget _requestButton(BuildContext context, AppLocalizations l10n, String projectId) =>
      FilledButton.tonalIcon(
        onPressed: () =>
            context.push('${AppRoutes.newRequest}?projectId=$projectId'),
        icon: const Icon(Icons.add, size: 18),
        label: Text(l10n.requestMaterial),
      );

  Widget _cards(BuildContext context, AppLocalizations l10n) {
    final status = context.statusColors;
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: controller.projects.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final p = controller.projects[i];
        return EntityCard(
          eyebrow: l10n.colProject,
          railColor: status.forProject(p.status).ink,
          title: p.particular,
          trailing: _ProjectStatus(p.status),
          fields: [
            EntityField(l10n.colClient, text: p.clientName),
            EntityField(l10n.colPo, text: p.po, muted: true),
            EntityField(l10n.colDate, text: formatDate(p.date)),
          ],
          footer: SizedBox(
            width: double.infinity,
            child: _requestButton(context, l10n, p.id),
          ),
        );
      },
    );
  }

  Widget _table(BuildContext context, AppLocalizations l10n) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final status = context.statusColors;
    return DcplTable(
      columns: [
        DcplColumn(l10n.colProject, flex: 3),
        DcplColumn(l10n.colClient, flex: 2),
        DcplColumn(l10n.colPo, fixedWidth: 110, numeric: true),
        DcplColumn(l10n.colDate, fixedWidth: 96, numeric: true),
        DcplColumn(l10n.colStatus, fixedWidth: 160),
        const DcplColumn('', fixedWidth: 190),
      ],
      rows: [
        for (final p in controller.projects)
          DcplRow(
            railColor: status.forProject(p.status).ink,
            cells: [
              PrimaryCell(p.particular),
              Text(p.clientName),
              Text(p.po, style: TextStyle(color: muted)),
              Text(formatDate(p.date)),
              _ProjectStatus(p.status),
              _requestButton(context, l10n, p.id),
            ],
          ),
      ],
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
      label: Text(
        active ? l10n.statusActive : l10n.statusCompleted,
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
