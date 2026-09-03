import 'package:flutter_test/flutter_test.dart';
import 'package:oasx/modules/home/models/script_analysis_models.dart';
import 'package:oasx/modules/log/log_browser_models.dart';

ScriptLogLine line(int number, String text) => ScriptLogLine(
      fileName: '2026-09-03_demo.txt',
      lineNo: number,
      offset: number * 100,
      byteLength: text.length,
      text: text,
      lineTruncated: false,
    );

void main() {
  test('parses clicks, swipes, tasks, and random click density', () {
    final result = parseScriptAnalysis([
      line(1, '2026-09-03 08:24:44.378 | logger.py | INFO | [Task] AreaBoss (Enable, 5, now)'),
      line(2, '2026-09-03 08:25:05.667 | control.py | INFO | [0.05s] Click ( 664,  409) @ SAFE_RANDOM_CLICK'),
      line(3, '2026-09-03 08:25:20.000 | control.py | INFO | [0.05s] Click ( 100,  200) @ CONFIRM'),
      line(4, '2026-09-03 08:26:20.000 | control.py | INFO | [0.20s] Swipe (100, 200) -> (300, 400)'),
      line(5, '2026-09-02 08:26:20.000 | control.py | INFO | [0.05s] Click (1, 2) @ OLD'),
    ], '2026-09-03');

    expect(result.clickCount, 2);
    expect(result.randomClickCount, 1);
    expect(result.taskCount, 1);
    expect(result.clicksByTask['AreaBoss'], 2);
    expect(result.events.last.kind, ScriptActionKind.swipe);
    expect(result.randomClicksPerMinute.single.value, 1);
  });
}
