import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_nb_net/flutter_net.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/api/sse_client.dart';
import 'package:oasx/modules/log/script_log_browser_controller.dart';
import 'package:oasx/api/api_interceptor.dart';
import 'package:oasx/api/log_api_response.dart';
import 'package:oasx/modules/log/models/error_log_ownership.dart';
import 'package:oasx/modules/log/log_browser_models.dart';

class _Adapter implements HttpClientAdapter {
  late ResponseBody Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? body,
    Future<void>? cancelFuture,
  ) async => respond(options);
  @override
  void close({bool force = false}) {}
}

// Keep production response/error handling, but avoid showing a snackbar in tests.
class _SilentInterceptor extends ApiInterceptor {
  @override
  void showNetErrCodeSnackBar(String msg, int code) {}
  @override
  void showErrSnackBar(String title, int code, String msg) {}
}

ResponseBody jsonResponse(Object body, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Map<String, dynamic> item(String id, [String? script]) => {
  'id': id,
  'directory': id,
  'script_name': script,
  'legacy': script == null,
  'timestamp_ms': 1788964567785,
  'time': '2026-09-09T22:36:07',
  'log_size': 120,
  'image_count': 0,
};

Map<String, dynamic> detail(String id, String text) => {
  ...item(id),
  'log': {
    'file_name': 'log.txt',
    'content': text,
    'size': text.length,
    'limit_bytes': 1048576,
    'truncated': false,
  },
  'images': <Object>[],
};

Map<String, dynamic> page(List<Object> items, {String? next}) => {
  'items': items,
  'has_more': next != null,
  'next_cursor': next,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final temporary = Directory.systemTemp.createTempSync('oasx-log-api-test-');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/connectivity'),
        (call) async => 'wifi',
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => temporary.path,
      );
  late ApiClient api;
  final adapter = _Adapter();
  var index = 0;
  setUpAll(() async {
    final storage = GetStorage('GetStorage', temporary.path);
    await storage.initStorage;
    await storage.write('temporaryDirectory', temporary.path);
    api = ApiClient();
    final dio = NetOptions.instance.dio;
    dio.httpClientAdapter = adapter;
    dio.interceptors.removeWhere((entry) => entry is ApiInterceptor);
    dio.interceptors.add(_SilentInterceptor());
  });
  setUp(() => api.setAddress('http://oasx-log-test-${index++}.invalid'));

  test(
    'stale stream cursor reloads latest window and replaces both cursors',
    () async {
      var requests = 0;
      adapter.respond = (request) {
        requests++;
        expect(request.queryParameters.containsKey('cursor'), isFalse);
        return jsonResponse({
          'script_name': 'demo',
          'lines': <Object>[],
          'older_cursor': null,
          'live_cursor': 'fresh-live',
          'has_older': false,
          'reached_start': true,
        });
      };
      final controller = ScriptLogBrowserController(scriptName: 'demo');
      controller.liveCursor = 'deleted-file';
      controller.olderCursor = 'deleted-history';
      controller.handleStreamEvent(
        ApiSseEvent(
          id: '',
          name: 'error',
          data:
              '{"code":"LOG_CURSOR_STALE","message":"Cursor file is no longer available"}',
        ),
      );
      for (var i = 0; i < 50 && controller.liveCursor != 'fresh-live'; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(requests, 1);
      expect(controller.liveCursor, 'fresh-live');
      expect(controller.olderCursor, isNull);
      controller.onClose();
    },
  );

  for (final endpoint in ['window', 'errors', 'detail', 'image']) {
    test('$endpoint HTTP failure throws actual status and message', () async {
      adapter.respond = (_) =>
          jsonResponse({'detail': 'fixture log unavailable'}, 404);
      Future<Object?> call() => switch (endpoint) {
        'window' => api.getScriptLogWindow('oas1'),
        'errors' => api.getScriptErrorLogs(scriptName: 'oas1'),
        'detail' => api.getScriptErrorLogDetail('1788964567785'),
        _ => api.getScriptErrorImage('1788964567785', 'test.png'),
      };
      await expectLater(
        call(),
        throwsA(
          isA<LogApiException>()
              .having((e) => e.statusCode, 'status', 404)
              .having(
                (e) => e.toString(),
                'message',
                contains('fixture log unavailable'),
              ),
        ),
      );
    });
  }

  test('malformed successful response is not an empty log', () async {
    adapter.respond = (_) => jsonResponse({'unexpected': 'payload'});
    await expectLater(
      api.getScriptLogWindow('oas1'),
      throwsA(isA<LogApiException>()),
    );
    await expectLater(
      api.getScriptErrorLogs(),
      throwsA(isA<LogApiException>()),
    );
    await expectLater(
      api.getScriptErrorLogDetail('1788964567785'),
      throwsA(isA<LogApiException>()),
    );
  });

  test('genuinely empty log responses remain valid', () async {
    adapter.respond = (request) => request.path == '/logs/errors'
        ? jsonResponse(page([]))
        : jsonResponse({'lines': []});
    expect((await api.getScriptLogWindow('oas1')).lines, isEmpty);
    expect((await api.getScriptErrorLogs(scriptName: 'oas1')).items, isEmpty);
  });

  test(
    'legacy ownership, unknown group, pagination and cached reads',
    () async {
      var detailReads = 0;
      adapter.respond = (request) {
        if (request.path == '/logs/errors') {
          expect(request.queryParameters.containsKey('script_name'), isFalse);
          if (!request.queryParameters.containsKey('cursor')) {
            return jsonResponse(
              page([item('oas2_1788964567780', 'oas2')], next: 'second'),
            );
          }
          return jsonResponse(
            page([
              item('1788964567785'),
              item('1788964567786'),
              item('1788964567787'),
            ]),
          );
        }
        detailReads++;
        final id = request.path.split('/').last;
        return jsonResponse(
          detail(id, switch (id) {
            '1788964567785' =>
              '2026-09-09 22:36:00.000 | INFO | Start scheduler loop: oas1',
            '1788964567786' =>
              '[Task] RealmRaid (Enable)\nValueError: no config identity',
            _ => 'Start scheduler loop: oas2',
          }),
        );
      };
      final result = await api.getScriptErrorLogs(scriptName: 'oas1');
      expect(result.items.map((e) => e.id), ['1788964567785', '1788964567786']);
      expect(result.items.map((e) => e.scriptName), ['oas1', null]);
      expect(result.hasMore, isFalse);
      await api.getScriptErrorLogs(scriptName: 'oas1');
      expect(detailReads, 3);
    },
  );

  test(
    'failed ownership lookup stays retryable instead of becoming unknown',
    () async {
      var fail = true;
      adapter.respond = (request) {
        if (request.path == '/logs/errors') {
          return jsonResponse(page([item('1788964567785')]));
        }
        return fail
            ? jsonResponse({'detail': 'read failed'}, 500)
            : jsonResponse(
                detail('1788964567785', 'Start scheduler loop: oas1'),
              );
      };
      await expectLater(
        api.getScriptErrorLogs(scriptName: 'oas1'),
        throwsA(isA<LogApiException>()),
      );
      fail = false;
      expect(
        (await api.getScriptErrorLogs(
          scriptName: 'oas1',
        )).items.single.scriptName,
        'oas1',
      );
    },
  );

  test(
    'repeated paging cursor fails instead of hiding older results',
    () async {
      adapter.respond = (_) => jsonResponse(
        page([item('oas2_1788964567780', 'oas2')], next: 'same'),
      );
      await expectLater(
        api.getScriptErrorLogs(scriptName: 'oas1'),
        throwsA(isA<LogApiException>()),
      );
    },
  );

  test('task titles and conflicting identities never determine a config', () {
    expect(
      inferErrorLogScriptName('[Task] Oas1 (Enable)\nNotifier: OAS1'),
      isNull,
    );
    expect(
      inferErrorLogScriptName('Start scheduler loop: oas1\n[Config] oas2'),
      isNull,
    );
    expect(
      inferErrorLogScriptName('Start scheduler loop: oas1', truncated: true),
      isNull,
    );
    expect(inferErrorLogScriptName('[ConfigName] mumu-1'), 'mumu-1');
    expect(inferErrorLogScriptName('Script oas1 process exit'), 'oas1');
    final legacy = ScriptErrorLogItem.fromJson(
      item('1788964567785'),
    ).withScriptName('oas');
    expect(errorLogBelongsInView(legacy, 'oas_2'), isFalse);
  });

  test(
    'empty screenshot bytes fail rather than creating a broken report',
    () async {
      adapter.respond = (_) => ResponseBody.fromBytes([], 200);
      await expectLater(
        api.getScriptErrorImage('1788964567785', 'test.png'),
        throwsA(isA<LogApiException>()),
      );
    },
  );
}
