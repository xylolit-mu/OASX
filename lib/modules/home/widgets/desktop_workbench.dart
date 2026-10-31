import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/modules/common/models/config_drag_payload.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/models/config_model.dart';
import 'package:oasx/modules/home/models/home_workbench_layout.dart';
import 'package:oasx/modules/home/models/script_statistics_models.dart';
import 'package:oasx/modules/home/widgets/config_collection_task_preview.dart';
import 'package:oasx/modules/home/widgets/config_state_indicator.dart';
import 'package:oasx/modules/home/widgets/home_workbench_body.dart';
import 'package:oasx/modules/home/widgets/task_catalog_panel.dart';
import 'package:oasx/modules/home/widgets/task_parameter_panel.dart';
import 'package:oasx/modules/home/widgets/task_status_panel.dart';
import 'package:oasx/modules/home/widgets/log_center_panel.dart';
import 'package:oasx/modules/home/widgets/statistics_panel.dart';
import 'package:oasx/modules/home/widgets/analysis_panel.dart';
import 'package:oasx/modules/home/widgets/workbench_sidebar_panel.dart';
import 'package:oasx/translation/i18n_content.dart';

/// Fade only decorative surfaces; preserve text, status colors and illustration settings.
ThemeData desktopWorkbenchTheme(ThemeData theme) {
  final colors = theme.colorScheme;
  Color fade(Color value) => value.withValues(alpha: value.a * .5);
  return theme.copyWith(
    colorScheme: colors.copyWith(
      primaryContainer: fade(colors.primaryContainer),
      secondaryContainer: fade(colors.secondaryContainer),
      tertiaryContainer: fade(colors.tertiaryContainer),
      surfaceContainerLowest: fade(colors.surfaceContainerLowest),
      surfaceContainerLow: fade(colors.surfaceContainerLow),
      surfaceContainer: fade(colors.surfaceContainer),
      surfaceContainerHigh: fade(colors.surfaceContainerHigh),
      surfaceContainerHighest: fade(colors.surfaceContainerHighest),
      outlineVariant: fade(colors.outlineVariant),
    ),
    cardTheme: theme.cardTheme.copyWith(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: fade(theme.cardTheme.color ?? colors.surfaceContainerLow),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .3)),
      ),
    ),
    chipTheme: theme.chipTheme.copyWith(
      selectedColor: fade(colors.secondaryContainer),
      backgroundColor: fade(colors.surfaceContainerLow),
      side: BorderSide(color: colors.outlineVariant.withValues(alpha: .3)),
    ),
  );
}

/// The desktop arrangement reuses the existing actions, editors and pane dividers.
class DesktopWorkbench extends StatefulWidget {
  const DesktopWorkbench({
    super.key,
    required this.controller,
    required this.legacy,
    required this.loadingAddScript,
    required this.refreshingScripts,
    required this.onAddScript,
    required this.onRefreshScripts,
    required this.onActivateScript,
    required this.onTogglePower,
    required this.onRenameScript,
    required this.onExportScript,
    required this.onDeleteScript,
    required this.onOpenTask,
    required this.onSetNextRun,
    required this.onQuickRun,
    required this.onQuickWait,
    required this.onBulkQuickRun,
    required this.onBulkQuickWait,
    required this.onChangeTab,
  });
  final HomeDashboardController controller;
  final HomeWorkbenchBody legacy;
  final bool loadingAddScript;
  final bool refreshingScripts;
  final VoidCallback onAddScript;
  final VoidCallback onRefreshScripts;
  final Future<void> Function(String) onActivateScript;
  final Future<void> Function(String, bool) onTogglePower;
  final Future<void> Function(String) onRenameScript;
  final Future<void> Function(String) onExportScript;
  final Future<void> Function(String) onDeleteScript;
  final Future<void> Function(String, HomeTaskParameterEntrySource) onOpenTask;
  final Future<void> Function(String, String) onSetNextRun;
  final Future<void> Function(String) onQuickRun;
  final Future<void> Function(String) onQuickWait;
  final Future<void> Function() onBulkQuickRun;
  final Future<void> Function() onBulkQuickWait;
  final Future<void> Function(HomeWorkbenchTab) onChangeTab;
  @override
  State<DesktopWorkbench> createState() => _DesktopWorkbenchState();
}

class _DesktopWorkbenchState extends State<DesktopWorkbench> {
  DateTime? _selectedDate;
  bool _showCatalog = false;
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _manageScripts() => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: SizedBox(
        width: 520,
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: I18n.back.tr,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Expanded(
              child: widget.legacy.collectionBuilder(
                HomeWorkbenchLayoutMode.threePane,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: desktopWorkbenchTheme(Theme.of(context)),
      child: Builder(
        builder: (context) => LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                SizedBox(
                  height: 66,
                  child: DesktopScriptStrip(
                    controller: widget.controller,
                    onActivate: (name) async {
                      await widget.onActivateScript(name);
                      if (mounted) setState(() => _selectedDate = null);
                    },
                    onTogglePower: widget.onTogglePower,
                    onManage: _manageScripts,
                    onAdd: widget.onAddScript,
                    onRefresh: widget.onRefreshScripts,
                    loadingAdd: widget.loadingAddScript,
                    refreshing: widget.refreshingScripts,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: HomeWorkbenchBody(
                    controller: widget.controller,
                    balancedColumns: true,
                    collectionBuilder: (mode) => Obx(() {
                      final script = widget.controller.activeScriptModel;
                      if (script == null) return _empty();
                      return Column(
                        children: [
                          _summary(script),
                          const SizedBox(height: 12),
                          Expanded(
                            child: mode == HomeWorkbenchLayoutMode.threePane
                                ? _catalog(context, script)
                                : LogCenterPanel(
                                    key: const ValueKey('compact-left-logs'),
                                    scriptName: script.name,
                                  ),
                          ),
                        ],
                      );
                    }),
                    detailsBuilder: (mode, expand) => Obx(() {
                      final script = widget.controller.activeScriptModel;
                      if (script == null) return _empty();
                      final full = mode == HomeWorkbenchLayoutMode.threePane;
                      return Column(
                        children: [
                          SizedBox(
                            height: 140,
                            child: _dateCard(script, expand),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: full
                                ? _taskArea(context, script)
                                : _compactRight(context, script),
                          ),
                        ],
                      );
                    }),
                    sidebar: Obx(
                      () => WorkbenchSidebarPanel(
                        controller: widget.controller,
                        scriptName: widget.controller.activeScriptName.value,
                        separateHeader: true,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dateCard(ScriptModel script, VoidCallback? expand) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(right: expand == null ? 0 : 40),
              child: TaskDateDistribution(
                script: script,
                selectedDate: _selectedDate,
                onSelected: (value) => setState(() => _selectedDate = value),
              ),
            ),
          ),
          if (expand != null)
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                key: const ValueKey('home-workbench-expand-right-sidebar'),
                tooltip: I18n.homeRestoreSidebar.tr,
                onPressed: expand,
                icon: const Icon(Icons.keyboard_double_arrow_left_rounded),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _catalog(BuildContext context, ScriptModel script) => Card(
    key: const ValueKey('desktop-task-catalog'),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                I18n.overview.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '已启用 ${widget.controller.enabledTaskNamesFor(script).length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                tooltip: '刷新',
                onPressed: widget.onRefreshScripts,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          Expanded(
            child: TaskCatalogPanel(
              controller: widget.controller,
              scriptModel: script,
              gridLayout: true,
              inlineParameters: false,
              onOpenTask: (task) =>
                  widget.onOpenTask(task, HomeTaskParameterEntrySource.tasks),
              onQuickRun: widget.onQuickRun,
              onQuickWait: widget.onQuickWait,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _taskArea(BuildContext context, ScriptModel script) {
    if (widget.controller.activeTaskName.value.isNotEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: TaskParameterPanel(
            controller: widget.controller,
            scriptModel: script,
            onBack: widget.controller.closeTaskParameters,
          ),
        ),
      );
    }
    return _tasks(context, script);
  }

  Widget _tasks(BuildContext context, ScriptModel script) => Card(
    key: const ValueKey('desktop-task-schedule'),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                I18n.homeTasksTab.tr,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              if (_selectedDate != null)
                TextButton(
                  onPressed: () => setState(() => _selectedDate = null),
                  child: const Text('全部日期'),
                ),
              IconButton(
                tooltip: I18n.homeQuickRunAll.tr,
                onPressed: widget.controller.isBulkQuickScheduling
                    ? null
                    : widget.onBulkQuickRun,
                icon: const Icon(Icons.flash_on_rounded, size: 18),
              ),
              IconButton(
                tooltip: I18n.homeQuickWaitAll.tr,
                onPressed: widget.controller.isBulkQuickScheduling
                    ? null
                    : widget.onBulkQuickWait,
                icon: const Icon(Icons.schedule_rounded, size: 18),
              ),
            ],
          ),
          Expanded(
            child: TaskStatusPanel(
              controller: widget.controller,
              scriptModel: script,
              scheduledDate: _selectedDate,
              compact: true,
              canQuickScheduleTask: (task) =>
                  widget.controller.canQuickScheduleTask(script, task),
              onSetNextRun: widget.onSetNextRun,
              onQuickRun: widget.onQuickRun,
              onQuickWait: widget.onQuickWait,
              onEditTask: (task) => widget.onOpenTask(
                task,
                HomeTaskParameterEntrySource.overview,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _selectCompactTab(
    HomeWorkbenchTab tab, {
    bool catalog = false,
  }) async {
    await widget.onChangeTab(tab);
    if (!mounted || widget.controller.activeWorkbenchTab.value != tab) return;
    setState(() {
      _showCatalog = catalog;
    });
  }

  Widget _compactRight(
    BuildContext context,
    ScriptModel script,
  ) => LayoutBuilder(
    builder: (context, constraints) => Obx(() {
      final sideBySide = constraints.maxWidth >= 700;
      final activeTab = widget.controller.activeWorkbenchTab.value;
      final currentTab =
          activeTab == HomeWorkbenchTab.stats ||
              activeTab == HomeWorkbenchTab.analysis
          ? activeTab
          : HomeWorkbenchTab.status;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              ChoiceChip(
                label: const Text('任务'),
                showCheckmark: false,
                selected:
                    currentTab == HomeWorkbenchTab.status && !_showCatalog,
                onSelected: (_) => _selectCompactTab(HomeWorkbenchTab.status),
              ),
              if (!sideBySide)
                ChoiceChip(
                  label: const Text('总览'),
                  showCheckmark: false,
                  selected:
                      currentTab == HomeWorkbenchTab.status && _showCatalog,
                  onSelected: (_) =>
                      _selectCompactTab(HomeWorkbenchTab.status, catalog: true),
                ),
              for (final tab in [
                HomeWorkbenchTab.stats,
                HomeWorkbenchTab.analysis,
              ])
                ChoiceChip(
                  label: Text(
                    (tab == HomeWorkbenchTab.stats
                            ? I18n.homeStatsTab
                            : I18n.homeAnalysisTab)
                        .tr,
                  ),
                  showCheckmark: false,
                  selected: currentTab == tab,
                  onSelected: (_) => _selectCompactTab(tab),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: widget.controller.activeTaskName.value.isNotEmpty
                ? _taskArea(context, script)
                : switch (currentTab) {
                    HomeWorkbenchTab.stats => const Card(
                      child: ScriptStatisticsPanel(),
                    ),
                    HomeWorkbenchTab.analysis => Card(
                      child: ScriptAnalysisPanel(scriptName: script.name),
                    ),
                    _ =>
                      sideBySide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: _catalog(context, script)),
                                const SizedBox(width: 12),
                                Expanded(child: _tasks(context, script)),
                              ],
                            )
                          : (_showCatalog
                                ? _catalog(context, script)
                                : _tasks(context, script)),
                  },
          ),
        ],
      );
    }),
  );

  Widget _empty() =>
      Card(child: Center(child: Text(I18n.homeNoScriptSelected.tr)));

  Widget _summary(ScriptModel script) {
    final running = script.state.value == ScriptState.running;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    script.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: I18n.homeQuickRunAll.tr,
                  onPressed: widget.controller.isBulkQuickScheduling
                      ? null
                      : widget.onBulkQuickRun,
                  icon: const Icon(Icons.flash_on_rounded, size: 18),
                ),
                IconButton(
                  tooltip: '脚本联动',
                  onPressed: widget.controller.toggleLinkMode,
                  icon: Icon(
                    widget.controller.isLinkModeEnabled.value
                        ? Icons.link
                        : Icons.link_off,
                    size: 18,
                  ),
                ),
                IconButton(
                  tooltip: (running ? I18n.stop : I18n.run).tr,
                  iconSize: 18,
                  onPressed: widget.controller.isDragCopyPendingFor(script.name)
                      ? null
                      : () => widget.onTogglePower(script.name, !running),
                  icon: const Icon(Icons.power_settings_new_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: ConfigCollectionTaskPreview(script: script)),
                PopupMenuButton<String>(
                  tooltip: '配置操作',
                  onSelected: (value) {
                    switch (value) {
                      case 'rename':
                        widget.onRenameScript(script.name);
                        break;
                      case 'export':
                        widget.onExportScript(script.name);
                        break;
                      case 'delete':
                        widget.onDeleteScript(script.name);
                        break;
                      case 'manage':
                        _manageScripts();
                        break;
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('重命名')),
                    PopupMenuItem(value: 'export', child: Text('导出配置')),
                    PopupMenuItem(value: 'delete', child: Text('删除配置')),
                    PopupMenuItem(value: 'manage', child: Text('调整计划 / 管理脚本')),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Text('调整计划 ▾'),
                  ),
                ),
              ],
            ),
            const Divider(height: 12),
            DesktopSummaryMetrics(
              key: ValueKey(script.name),
              scriptName: script.name,
            ),
          ],
        ),
      ),
    );
  }
}

/// Next-run dates, not speculative future recurring executions.
Map<DateTime, int> scheduledDayCounts(ScriptModel script) {
  final counts = <DateTime, int>{};
  for (final task in [...script.pendingTaskList, ...script.waitingTaskList]) {
    final date = DateTime.tryParse(task.nextRun.value);
    if (date == null) continue;
    final day = DateTime(date.year, date.month, date.day);
    counts[day] = (counts[day] ?? 0) + 1;
  }
  return counts;
}

class TaskDateDistribution extends StatelessWidget {
  const TaskDateDistribution({
    super.key,
    required this.script,
    required this.selectedDate,
    required this.onSelected,
  });
  final ScriptModel script;
  final DateTime? selectedDate;
  final ValueChanged<DateTime?> onSelected;
  @override
  Widget build(BuildContext context) => Obx(() {
    final counts = scheduledDayCounts(script);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text('任务日期分布'),
            const SizedBox(width: 8),
            Text('未来7天', style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Text(
              '共${counts.values.fold<int>(0, (a, b) => a + b)}项',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        Expanded(
          child: Center(
            key: const ValueKey('task-date-distribution-center'),
            child: Row(
              children: [
                for (var i = 0; i < 8; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final date = DateTime(
                          today.year,
                          today.month,
                          today.day + i,
                        );
                        final selected = selectedDate == date;
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onSelected(selected ? null : date),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                i == 0
                                    ? '今天'
                                    : [
                                        '周一',
                                        '周二',
                                        '周三',
                                        '周四',
                                        '周五',
                                        '周六',
                                        '周日',
                                      ][date.weekday - 1],
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              const SizedBox(height: 10),
                              Container(
                                height: 38,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(9),
                                  color: selected
                                      ? colors.primaryContainer
                                      : colors.surfaceContainerHigh,
                                  border: Border.all(
                                    color: selected
                                        ? colors.primary.withValues(alpha: .35)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  '${counts[date] ?? 0}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  });
}

/// Compact real today metrics; failures remain unknown instead of becoming fake zeros.
class DesktopSummaryMetrics extends StatefulWidget {
  const DesktopSummaryMetrics({super.key, required this.scriptName});
  final String scriptName;
  @override
  State<DesktopSummaryMetrics> createState() => _DesktopSummaryMetricsState();
}

class _DesktopSummaryMetricsState extends State<DesktopSummaryMetrics> {
  ScriptStatisticsDay? _stats;
  Timer? _timer;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      final date = DateTime.now().toIso8601String().substring(0, 10);
      final result = await ApiClient().getScriptStatisticsDay(
        widget.scriptName,
        date,
      );
      if (mounted) setState(() => _stats = result);
    } catch (_) {
      if (mounted) setState(() => _stats = null);
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _stats?.totalRuntimeSeconds.toInt();
    final values = [
      seconds == null ? '—' : '${seconds ~/ 3600}h ${seconds % 3600 ~/ 60}m',
      _stats?.totalTaskRunCount.toString() ?? '—',
      _stats?.totalBattleCount.toString() ?? '—',
    ];
    return Row(
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ['今日运行', '任务次数', '战斗场次'][i],
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 3),
                Text(values[i], style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
      ],
    );
  }
}

/// Horizontal tabs keep existing multi-config power, linking and drag-copy actions.
class DesktopScriptStrip extends StatefulWidget {
  const DesktopScriptStrip({
    super.key,
    required this.controller,
    required this.onActivate,
    required this.onTogglePower,
    required this.onManage,
    required this.onAdd,
    required this.onRefresh,
    required this.loadingAdd,
    required this.refreshing,
  });
  final HomeDashboardController controller;
  final Future<void> Function(String) onActivate;
  final Future<void> Function(String, bool) onTogglePower;
  final VoidCallback onManage;
  final VoidCallback onAdd;
  final VoidCallback onRefresh;
  final bool loadingAdd;
  final bool refreshing;
  @override
  State<DesktopScriptStrip> createState() => _DesktopScriptStripState();
}

class _DesktopScriptStripState extends State<DesktopScriptStrip> {
  final ScrollController _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(double delta) {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      (_scroll.offset + delta).clamp(0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) => Obx(() {
    final scripts = widget.controller.orderedScripts;
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        IconButton(
          tooltip: '向左滚动',
          onPressed: () => _move(-280),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: ScrollbarTheme(
            data: ScrollbarTheme.of(context).copyWith(
              thickness: const WidgetStatePropertyAll(6),
              thumbColor: WidgetStateProperty.resolveWith(
                (states) => colors.onSurface.withValues(
                  alpha: states.contains(WidgetState.dragged) ? .55 : .10,
                ),
              ),
            ),
            child: Scrollbar(
              controller: _scroll,
              thumbVisibility: true,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: ListView.separated(
                key: const ValueKey('desktop-script-strip'),
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 16, top: 4),
                itemCount: scripts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final script = scripts[index];
                  return Obx(() {
                    final active =
                        widget.controller.activeScriptName.value == script.name;
                    final running = script.state.value == ScriptState.running;
                    final linking = widget.controller.isLinkModeEnabled.value;
                    // Read selection inside Obx, before DragTarget's deferred builder.
                    final linked = widget.controller.isScriptLinked(
                      script.name,
                    );
                    return DragTarget<ConfigDragPayload>(
                      onWillAcceptWithDetails: (details) =>
                          details.data.canDropOn(script.name) &&
                          !widget.controller.isDragCopyPendingFor(script.name),
                      onMove: (details) {
                        final box = context.findRenderObject();
                        if (box is RenderBox) {
                          final x = box.globalToLocal(details.offset).dx;
                          if (x < 32) _move(-60);
                          if (x > box.size.width - 32) _move(60);
                        }
                      },
                      onAcceptWithDetails: (details) async {
                        widget.controller.clearConfigDrag();
                        await widget.controller.acceptConfigDrag(
                          payload: details.data,
                          destinationConfig: script.name,
                        );
                      },
                      builder: (context, candidates, _) => Material(
                        color: active || candidates.isNotEmpty
                            ? colors.primaryContainer
                            : colors.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: active
                                ? colors.primary.withValues(alpha: .4)
                                : colors.outlineVariant,
                          ),
                        ),
                        child: InkWell(
                          onTap: () => widget.onActivate(script.name),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 10, right: 2),
                            child: Row(
                              children: [
                                if (linking)
                                  Checkbox(
                                    value: linked,
                                    visualDensity: VisualDensity.compact,
                                    onChanged: (value) =>
                                        widget.controller.setScriptLinked(
                                          script.name,
                                          value ?? false,
                                        ),
                                  ),
                                ConfigStateIndicator(
                                  state: widget.controller.scriptStateFor(
                                    script,
                                  ),
                                  size: 10,
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 132,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        script.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelMedium,
                                      ),
                                      const SizedBox(height: 2),
                                      ConfigCollectionTaskPreview(
                                        key: ValueKey(
                                          'script-strip-task-${script.name}',
                                        ),
                                        script: script,
                                        compact: true,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: (running ? I18n.stop : I18n.run).tr,
                                  iconSize: 18,
                                  onPressed:
                                      widget.controller.isDragCopyPendingFor(
                                        script.name,
                                      )
                                      ? null
                                      : () => widget.onTogglePower(
                                          script.name,
                                          !running,
                                        ),
                                  icon: const Icon(
                                    Icons.power_settings_new_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  });
                },
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: '向右滚动',
          onPressed: () => _move(280),
          icon: const Icon(Icons.chevron_right),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: '新增脚本',
          onPressed: widget.loadingAdd ? null : widget.onAdd,
          icon: const Icon(Icons.add),
        ),
        IconButton(
          tooltip: '刷新',
          onPressed: widget.refreshing ? null : widget.onRefresh,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: '管理脚本 / 搜索 / 筛选',
          onPressed: widget.onManage,
          icon: const Icon(Icons.tune),
        ),
      ],
    );
  });
}
