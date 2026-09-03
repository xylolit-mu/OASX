import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/modules/home/models/script_analysis_models.dart';
import 'package:oasx/modules/log/log_browser_models.dart';
import 'package:oasx/translation/i18n_content.dart';

class ScriptAnalysisPanel extends StatefulWidget {
  const ScriptAnalysisPanel({super.key, required this.scriptName});

  final String scriptName;

  @override
  State<ScriptAnalysisPanel> createState() => _ScriptAnalysisPanelState();
}

class _ScriptAnalysisPanelState extends State<ScriptAnalysisPanel> {
  List<String> _dates = const [];
  String _dateKey = '';
  ScriptAnalysisSnapshot? _snapshot;
  Map<String, ScriptAnalysisSnapshot> _recentSnapshots = const {};
  bool _loading = true;
  bool _showClicks = true;
  bool _showSwipes = true;
  bool _showPath = true;
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    _loadDates();
  }

  @override
  void didUpdateWidget(covariant ScriptAnalysisPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scriptName != widget.scriptName) _loadDates();
  }

  Future<void> _loadDates() async {
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _snapshot = null;
    });
    try {
      final response = await ApiClient().getScriptStatisticsDates(widget.scriptName);
      if (!mounted || revision != _revision) return;
      _dates = response.dates;
      _dateKey = _dates.isEmpty ? DateFormat('yyyy-MM-dd').format(DateTime.now()) : _dates.first;
      await _loadAnalysis(revision);
    } catch (_) {
      if (!mounted || revision != _revision) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _loadAnalysis([int? expectedRevision]) async {
    final revision = expectedRevision ?? ++_revision;
    setState(() {
      _loading = true;
      _snapshot = null;
    });
    try {
      final byKey = <String, ScriptLogLine>{};
      final trendDates = _dates.take(7).toList();
      final oldestRequiredDate = trendDates.isEmpty ? _dateKey : trendDates.last;
      String? cursor;
      for (var page = 0; page < 100; page++) {
        final window = await ApiClient().getScriptLogWindow(
          widget.scriptName,
          cursor: cursor,
          limitLines: 2000,
          limitBytes: 2097152,
        );
        for (final line in window.lines) {
          byKey[line.key] = line;
        }
        final oldest = window.lines.isEmpty ? '' : window.lines.first.text;
        if (window.reachedStart ||
            !window.hasOlder ||
            oldest.compareTo(oldestRequiredDate) < 0) {
          break;
        }
        cursor = window.olderCursor;
        if (cursor == null || cursor.isEmpty) break;
      }
      final lines = byKey.values.toList()
        ..sort((left, right) {
          final fileCompare = left.fileName.compareTo(right.fileName);
          return fileCompare != 0
              ? fileCompare
              : left.lineNo.compareTo(right.lineNo);
        });
      final result = parseScriptAnalysis(lines, _dateKey);
      final recentSnapshots = <String, ScriptAnalysisSnapshot>{
        for (final date in trendDates) date: parseScriptAnalysis(lines, date),
      };
      if (!mounted || revision != _revision) return;
      setState(() {
        _snapshot = result;
        _recentSnapshots = recentSnapshots;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || revision != _revision) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final snapshot = _snapshot;
    return RefreshIndicator(
      onRefresh: () => _loadAnalysis(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(4),
        children: [
          _toolbar(),
          const SizedBox(height: 12),
          if (snapshot == null || snapshot.events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text(I18n.homeAnalysisEmpty.tr)),
            )
          else ...[
            _summary(snapshot),
            const SizedBox(height: 12),
            _pathCard(snapshot),
            const SizedBox(height: 12),
            _densityCard(snapshot),
            const SizedBox(height: 12),
            _rankingCard(snapshot),
          ],
        ],
      ),
    );
  }

  Widget _toolbar() {
    return Row(children: [
      const Icon(Icons.calendar_today_outlined, size: 18),
      const SizedBox(width: 8),
      DropdownButton<String>(
        value: _dates.contains(_dateKey) ? _dateKey : null,
        hint: Text(_dateKey),
        items: _dates.map((date) => DropdownMenuItem(value: date, child: Text(date))).toList(),
        onChanged: (date) {
          if (date == null) return;
          _dateKey = date;
          _loadAnalysis();
        },
      ),
      const Spacer(),
      IconButton(onPressed: _loadAnalysis, icon: const Icon(Icons.refresh)),
    ]);
  }

  Widget _summary(ScriptAnalysisSnapshot data) {
    return Wrap(spacing: 20, runSpacing: 8, children: [
      Text('${data.clickCount} ${I18n.homeAnalysisClicks.tr}'),
      Text('${data.randomClickCount} ${I18n.homeAnalysisRandomClicks.tr}'),
      Text('${data.taskCount} ${I18n.homeAnalysisTasks.tr}'),
    ]);
  }

  Widget _pathCard(ScriptAnalysisSnapshot data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(I18n.homeAnalysisPathTitle.tr, style: Theme.of(context).textTheme.titleMedium),
          Wrap(spacing: 8, children: [
            FilterChip(label: Text(I18n.homeAnalysisShowClicks.tr), selected: _showClicks, onSelected: (v) => setState(() => _showClicks = v)),
            FilterChip(label: Text(I18n.homeAnalysisShowSwipes.tr), selected: _showSwipes, onSelected: (v) => setState(() => _showSwipes = v)),
            FilterChip(label: Text(I18n.homeAnalysisShowPath.tr), selected: _showPath, onSelected: (v) => setState(() => _showPath = v)),
          ]),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLowest, borderRadius: BorderRadius.circular(8)),
              child: CustomPaint(painter: _ActionPathPainter(data.events, _showClicks, _showSwipes, _showPath, Theme.of(context).colorScheme)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _densityCard(ScriptAnalysisSnapshot data) {
    final values = data.randomClicksPerMinute;
    final dailyValues = _recentSnapshots.entries.toList().reversed.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(builder: (context, constraints) {
          final minute = _titledChart(
            I18n.homeAnalysisDensityTitle.tr,
            values.isEmpty
                ? null
                : _lineChart([
                    for (var i = 0; i < values.length; i++)
                      FlSpot(i.toDouble(), values[i].value.toDouble()),
                  ]),
          );
          final daily = _titledChart(
            I18n.homeAnalysisDailyTrendTitle.tr,
            dailyValues.isEmpty
                ? null
                : _lineChart(
                    [
                      for (var i = 0; i < dailyValues.length; i++)
                        FlSpot(
                          i.toDouble(),
                          dailyValues[i].value.randomClickCount.toDouble(),
                        ),
                    ],
                    bottomLabels: [
                      for (final entry in dailyValues) entry.key.substring(5),
                    ],
                  ),
          );
          if (constraints.maxWidth < 720) {
            return Column(children: [minute, const SizedBox(height: 16), daily]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: minute),
            const SizedBox(width: 16),
            Expanded(child: daily),
          ]);
        }),
      ),
    );
  }

  Widget _titledChart(String title, Widget? chart) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: chart ?? Center(child: Text(I18n.homeStatsChartEmpty.tr)),
          ),
        ],
      );

  Widget _lineChart(List<FlSpot> spots, {List<String> bottomLabels = const []}) {
    return LineChart(LineChartData(
      minY: 0,
      gridData: const FlGridData(show: true),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: bottomLabels.isNotEmpty,
            reservedSize: 28,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 ||
                  index >= bottomLabels.length ||
                  value != index.toDouble()) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  bottomLabels[index],
                  style: const TextStyle(fontSize: 9),
                ),
              );
            },
          ),
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          barWidth: 3,
          dotData: const FlDotData(show: true),
        ),
      ],
    ));
  }

  Widget _rankingCard(ScriptAnalysisSnapshot data) {
    final values = data.clicksByTask.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final shown = values.take(10).toList();
    return _chartCard(
      I18n.homeAnalysisRankingTitle.tr,
      shown.isEmpty
          ? Center(child: Text(I18n.homeStatsChartEmpty.tr))
          : BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(), rightTitles: const AxisTitles(),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 44, getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= shown.length) return const SizedBox.shrink();
                  final text = shown[index].key.tr;
                  return Padding(padding: const EdgeInsets.only(top: 6), child: Transform.rotate(angle: -math.pi / 5, child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9))));
                })),
              ),
              barGroups: [for (var i = 0; i < shown.length; i++) BarChartGroupData(x: i, barRods: [BarChartRodData(toY: shown[i].value.toDouble(), width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))])],
            )),
    );
  }

  Widget _chartCard(String title, Widget chart) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(height: 220, child: chart),
          ]),
        ),
      );
}

class _ActionPathPainter extends CustomPainter {
  _ActionPathPainter(this.events, this.showClicks, this.showSwipes, this.showPath, this.colors);
  final List<ScriptActionEvent> events;
  final bool showClicks;
  final bool showSwipes;
  final bool showPath;
  final ColorScheme colors;

  Offset _point(double x, double y, Size size) => Offset(x / 1280 * size.width, y / 720 * size.height);

  @override
  void paint(Canvas canvas, Size size) {
    final clicks = events.where((e) => e.kind == ScriptActionKind.click).toList();
    if (showPath && clicks.length > 1) {
      final path = Path()..moveTo(_point(clicks.first.startX, clicks.first.startY, size).dx, _point(clicks.first.startX, clicks.first.startY, size).dy);
      for (final event in clicks.skip(1)) {
        final point = _point(event.startX, event.startY, size);
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, Paint()..color = colors.primary.withValues(alpha: .55)..strokeWidth = 2..style = PaintingStyle.stroke);
    }
    if (showSwipes) {
      for (final event in events.where((e) => e.kind == ScriptActionKind.swipe)) {
        canvas.drawLine(_point(event.startX, event.startY, size), _point(event.endX, event.endY, size), Paint()..color = colors.tertiary..strokeWidth = 3);
      }
    }
    if (showClicks) {
      for (final event in clicks) {
        canvas.drawCircle(_point(event.startX, event.startY, size), event.isRandomClick ? 4 : 3, Paint()..color = event.isRandomClick ? colors.error : colors.primary);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ActionPathPainter oldDelegate) => true;
}
