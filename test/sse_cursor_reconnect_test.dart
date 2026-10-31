import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:oasx/api/sse_client.dart';

void main() {
  test('SSE reconnect resolves the newest cursor', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var cursor = 'old';
    final seen = <String?>[];
    final done = Completer<void>();
    final subscription = server.listen((request) async {
      seen.add(request.uri.queryParameters['cursor']);
      request.response.headers.contentType = ContentType(
        'text',
        'event-stream',
      );
      request.response.write('event: ready\ndata: {}\n\n');
      await request.response.close();
      if (seen.length >= 2 && !done.isCompleted) done.complete();
    });
    Uri url() => Uri.parse('http://127.0.0.1:${server.port}/?cursor=$cursor');
    final client = ApiSseClient(
      url: url(),
      urlProvider: url,
      retryDelay: const Duration(milliseconds: 20),
      onStateChanged: (_, __) {},
      onEvent: (_) => cursor = 'new',
    );
    try {
      await client.connect();
      await done.future.timeout(const Duration(seconds: 3));
      expect(seen.take(2), ['old', 'new']);
    } finally {
      await client.dispose();
      await subscription.cancel();
      await server.close(force: true);
    }
  });
}
