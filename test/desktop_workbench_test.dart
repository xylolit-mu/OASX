import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_nb_net/flutter_net.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/api/api_interceptor.dart';
import 'package:oasx/modules/args/index.dart';
import 'package:oasx/modules/home/controllers/dashboard_controller.dart';
import 'package:oasx/modules/home/controllers/statistics_controller.dart';
import 'package:oasx/modules/home/models/config_model.dart';
import 'package:oasx/modules/home/models/taskitem_model.dart';
import 'package:oasx/modules/home/widgets/config_workbench.dart';
import 'package:oasx/modules/home/widgets/desktop_workbench.dart';
import 'package:oasx/modules/home/widgets/task_parameter_panel.dart';
import 'package:oasx/modules/home/widgets/task_status_panel.dart';
import 'package:oasx/modules/home/widgets/task_status_row.dart';
import 'package:oasx/translation/i18n_content.dart';
import 'package:oasx/service/script_service.dart';
import 'package:oasx/service/websocket_service.dart';
import 'package:oasx/translation/i18n.dart';

class _Storage implements HomeDashboardStorage {
  final data = <String, dynamic>{};
  @override
  dynamic read(String key) => data[key];
  @override
  void write(String key, dynamic value) {
    data[key] = value;
  }
}

class _Scripts extends ScriptService {
  @override
  // Fixture initialization deliberately omits production network subscriptions.
  // ignore: must_call_super
  Future<void> onInit() async {}
  @override
  Future<void> onClose() async {}
}

class _Stats extends HomeStatisticsController {
  @override
  // Fixture initialization deliberately omits production SSE subscriptions.
  // ignore: must_call_super
  void onInit() {}
  @override
  void onClose() {}
}

class _Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async {
    final data = options.uri.path == '/script_menu'
        ? {
            'SoulZones': [
              'Orochi',
              'Sougenbi',
              'FallenSun',
              'EternitySea',
              'SixRealms',
              'OtherWorldTwilight',
            ],
            'DailyTask': ['Chess', 'Duel'],
          }
        : options.uri.path.startsWith('/stats/')
        ? {
            'script_name': 'CDB',
            'total_runtime_seconds': 7200,
            'total_task_run_count': 37,
            'total_battle_count': 104,
            'tasks': {},
          }
        : options.uri.path.startsWith('/logs/')
        ? {'lines': <Object>[]}
        : <String, dynamic>{};
    return ResponseBody.fromString(
      jsonEncode(data),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Quiet extends ApiInterceptor {
  @override
  void showNetErrCodeSnackBar(String msg, int code) {}
  @override
  void showErrSnackBar(String title, int code, String msg) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final temp = Directory.systemTemp.createTempSync('oasx-desktop-layout-');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (_) async => 'wifi',
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) async => temp.path,
      );
  setUpAll(() async {
    await GetStorage('GetStorage', temp.path).initStorage;
    await GetStorage().write('temporaryDirectory', temp.path);
    ApiClient().setAddress('http://desktop-layout.invalid');
    NetOptions.instance.dio.httpClientAdapter = _Adapter();
    NetOptions.instance.dio.interceptors.removeWhere(
      (entry) => entry is ApiInterceptor,
    );
    NetOptions.instance.dio.interceptors.add(_Quiet());
    expect((await ApiClient().getScriptMenu()).keys, contains('SoulZones'));
  });
  tearDown(() => Get.reset());

  HomeDashboardController setup() {
    Get.put(WebSocketService());
    final scripts = Get.put<ScriptService>(_Scripts());
    final now = DateTime.now();
    for (var i = 0; i < 25; i++) {
      final name = i == 0 ? 'CDB' : 'CDB-$i';
      final model = ScriptModel(name)..state.value = ScriptState.inactive;
      model.waitingTaskList.value = [
        for (var j = 0; j < 10; j++)
          TaskItemModel(
            name,
            [
              'Orochi',
              'Sougenbi',
              'FallenSun',
              'EternitySea',
              'Chess',
              'Duel',
              'RealmRaid',
              'RyouToppa',
              'Hunt',
              'TalismanPass',
            ][j],
            DateTime(
              now.year,
              now.month,
              now.day + j % 4,
              9,
              j,
            ).toIso8601String().replaceFirst('T', ' ').substring(0, 19),
          ),
      ];
      scripts.scriptModelMap[name] = model;
      scripts.scriptOrderList.add(name);
    }
    final controller = Get.put(HomeDashboardController(storage: _Storage()));
    controller.activeScriptName.value = 'CDB';
    controller.activeWorkbenchSidebarTab.value = HomeWorkbenchTab.stats;
    Get.put(ArgsController());
    Get.put<HomeStatisticsController>(_Stats());
    return controller;
  }

  test(
    'decorative alpha halves while foreground and theme remain unchanged',
    () {
      final original = ThemeData(colorSchemeSeed: const Color(0xff6750a4));
      final faded = desktopWorkbenchTheme(original);
      expect(
        faded.colorScheme.surfaceContainerHigh.a,
        closeTo(original.colorScheme.surfaceContainerHigh.a * .5, .001),
      );
      expect(faded.colorScheme.onSurface, original.colorScheme.onSurface);
      expect(faded.colorScheme.primary, original.colorScheme.primary);
      expect(original.colorScheme.surfaceContainerHigh.a, 1);
    },
  );

  testWidgets(
    'content-sized headers, centered distribution and horizontal overflow at 1600 and 1200',
    (tester) async {
      final controller = setup();
      final boundary = GlobalKey();
      tester.view.resetPhysicalSize();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1600, 1000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        GetMaterialApp(
          translations: Messages(),
          locale: const Locale('zh', 'CN'),
          theme: ThemeData(colorSchemeSeed: const Color(0xff6750a4)),
          home: Scaffold(
            body: RepaintBoundary(
              key: boundary,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ConfigWorkbench(
                  controller: controller,
                  scriptService: Get.find<ScriptService>(),
                  loadingAddScript: false,
                  refreshingScripts: false,
                  onAddScriptTap: () {},
                  onRefreshScriptsTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      final strip = find.byKey(const ValueKey('desktop-script-strip'));
      final stripTask = find.byKey(const ValueKey('script-strip-task-CDB'));
      expect(
        find.descendant(
          of: stripTask,
          matching: find.textContaining('09:00:00'),
        ),
        findsOneWidget,
      );
      final script = Get.find<ScriptService>().scriptModelMap['CDB']!;
      script.runningTask.value = TaskItemModel('CDB', 'Chess', '');
      await tester.pump();
      expect(
        find.descendant(of: stripTask, matching: find.text('百鬼棋局')),
        findsOneWidget,
      );
      script.runningTask.value = TaskItemModel('CDB', '', '');
      await tester.pump();
      expect(
        find.descendant(
          of: stripTask,
          matching: find.textContaining('09:00:00'),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(strip).height, lessThanOrEqualTo(66));
      final scrollbarTheme = tester
          .widget<ScrollbarTheme>(
            find
                .ancestor(of: strip, matching: find.byType(ScrollbarTheme))
                .first,
          )
          .data;
      expect(scrollbarTheme.thumbColor!.resolve({})!.a, closeTo(.10, .005));
      expect(
        scrollbarTheme.thumbColor!.resolve({WidgetState.dragged})!.a,
        greaterThan(.5),
      );
      expect(
        (tester.widget<ListView>(strip).padding! as EdgeInsets).bottom,
        16,
      );
      controller.toggleLinkMode();
      await tester.pump();
      final linkCheckbox = find
          .descendant(of: strip, matching: find.byType(Checkbox))
          .first;
      expect(tester.widget<Checkbox>(linkCheckbox).value, isFalse);
      await tester.tap(linkCheckbox);
      await tester.pump();
      expect(controller.isScriptLinked('CDB'), isTrue);
      expect(tester.widget<Checkbox>(linkCheckbox).value, isTrue);
      await tester.tap(linkCheckbox);
      await tester.pump();
      expect(controller.isScriptLinked('CDB'), isFalse);
      expect(tester.widget<Checkbox>(linkCheckbox).value, isFalse);
      controller.toggleLinkMode();
      await tester.pump();
      final scroll = tester.widget<ListView>(strip).controller!;
      final before = scroll.offset;
      await tester.tap(find.byTooltip('向右滚动'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(scroll.offset, greaterThan(before));
      final distribution = find.byType(TaskDateDistribution);
      final panel = tester.getRect(distribution);
      controller.activeWorkbenchSidebarTab.value = HomeWorkbenchTab.logs;
      await tester.pump(const Duration(milliseconds: 400));
      final logControls = tester.getRect(
        find.byKey(const ValueKey('desktop-log-controls')),
      );
      expect(logControls.height, lessThan(140));
      final dateCard = tester.getRect(
        find.ancestor(of: distribution, matching: find.byType(Card)).first,
      );
      expect(logControls.bottom, lessThan(dateCard.bottom));
      controller.activeWorkbenchSidebarTab.value = HomeWorkbenchTab.stats;
      await tester.pump(const Duration(milliseconds: 400));
      final bodyCenter = tester.getCenter(
        find.byKey(const ValueKey('task-date-distribution-center')),
      );
      expect(bodyCenter.dy, greaterThan(panel.top + 40));
      expect(bodyCenter.dy, lessThan(panel.bottom - 35));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(1200, 800);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(strip, findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('home-workbench-right-divider')),
        const Offset(-600, 0),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('compact-left-logs')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-workbench-expand-right-sidebar')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.byKey(const ValueKey('home-workbench-expand-right-sidebar')),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('compact-left-logs')), findsNothing);
      tester.view.physicalSize = const Size(1000, 800);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('compact-left-logs')), findsOneWidget);
      expect(find.text('执行列表'), findsNothing);
      expect(find.text('任务'), findsWidgets);
      expect(find.text('任务总览'), findsNothing);
      expect(find.text('总览'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Navigation must update without another window layout pass.
      for (var cycle = 0; cycle < 2; cycle++) {
        controller.activeTaskName.value = 'Chess';
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(TaskParameterPanel), findsOneWidget);
        expect(
          find.byKey(const ValueKey('desktop-task-schedule')),
          findsNothing,
        );
        final back = find.descendant(
          of: find.byType(TaskParameterPanel),
          matching: find.byIcon(Icons.arrow_back_rounded),
        );
        await tester.tap(back);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(TaskParameterPanel), findsNothing);
        final schedule = find.byKey(const ValueKey('desktop-task-schedule'));
        expect(schedule, findsOneWidget);
        expect(tester.getSize(schedule).width, greaterThan(300));
        expect(tester.takeException(), isNull);
      }
      tester.view.physicalSize = const Size(900, 760);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('compact-left-logs')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
    },
  );

  testWidgets('task actions unlock immediately after stop without resizing', (
    tester,
  ) async {
    final controller = setup();
    final model = Get.find<ScriptService>().scriptModelMap['CDB']!;
    model.runningTask.value = TaskItemModel('CDB', 'Orochi', '');
    var waits = 0;
    await tester.pumpWidget(
      GetMaterialApp(
        translations: Messages(),
        locale: const Locale('zh', 'CN'),
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: TaskStatusPanel(
              controller: controller,
              scriptModel: model,
              compact: true,
              canQuickScheduleTask: (name) =>
                  controller.canQuickScheduleTask(model, name),
              onSetNextRun: (_, __) async {},
              onQuickRun: (_) async {},
              onQuickWait: (_) async {
                waits++;
              },
              onEditTask: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final row = find.byKey(const ValueKey('running::Orochi'));
    final wait = find.descendant(
      of: row,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is IconButton && widget.tooltip == I18n.homeQuickWait.tr,
      ),
    );
    for (var cycle = 0; cycle < 3; cycle++) {
      model.state.value = ScriptState.running;
      await tester.pump();
      expect(tester.widget<IconButton>(wait).onPressed, isNull);
      expect(tester.widget<TaskStatusRow>(row).swipeEnabled, isFalse);
      model.state.value = ScriptState.inactive;
      await tester.pump();
      expect(tester.widget<IconButton>(wait).onPressed, isNotNull);
      expect(tester.widget<TaskStatusRow>(row).swipeEnabled, isTrue);
      await tester.tap(wait);
      await tester.pump();
    }
    expect(waits, 3);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('date distribution toggles actual next-run filtering', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final model = ScriptModel('test');
    model.waitingTaskList.add(
      TaskItemModel(
        'test',
        'Chess',
        DateTime(today.year, today.month, today.day + 1, 9).toIso8601String(),
      ),
    );
    expect(scheduledDayCounts(model).values.single, 1);
    DateTime? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 190,
            child: StatefulBuilder(
              builder: (context, update) => TaskDateDistribution(
                script: model,
                selectedDate: selected,
                onSelected: (date) => update(() => selected = date),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('今天'));
    await tester.pump();
    expect(selected, today);
    await tester.tap(find.text('今天'));
    await tester.pump();
    expect(selected, isNull);
  });
}
