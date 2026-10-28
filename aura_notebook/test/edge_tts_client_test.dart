import 'package:flutter_test/flutter_test.dart';
import 'package:aura_notebook/services/tts_service/edge_tts_client.dart';

void main() {
  group('EdgeTtsClient', () {
    test('secMsGec is stable inside a 5-minute window', () {
      final t = DateTime.utc(2026, 8, 15, 12, 1, 30);
      final a = EdgeTtsClient.secMsGec(now: t);
      final b = EdgeTtsClient.secMsGec(now: t.add(const Duration(minutes: 2)));
      expect(a.length, 64);
      expect(a, b);
      expect(RegExp(r'^[0-9A-F]{64}$').hasMatch(a), isTrue);
    });

    test('secMsGec changes across a 5-minute boundary', () {
      final t = DateTime.utc(2026, 8, 15, 12, 4, 50);
      final a = EdgeTtsClient.secMsGec(now: t);
      final b = EdgeTtsClient.secMsGec(now: t.add(const Duration(minutes: 2)));
      expect(a, isNot(b));
    });

    test('SSML escapes markup and uses the requested voice', () {
      final ssml = EdgeTtsClient.buildSsml(
        'Hello <world> & friends',
        'en-US-AriaNeural',
      );
      expect(ssml, contains("voice name='en-US-AriaNeural'"));
      expect(ssml, contains('Hello &lt;world&gt; &amp; friends'));
      expect(ssml, isNot(contains('<world>')));
    });

    test('websocket URL carries GEC and connection id', () {
      final client = EdgeTtsClient();
      final url = client.websocketUrl(
        now: DateTime.utc(2026, 8, 15, 12, 0),
        connectionId: 'abc123',
      );
      expect(url, startsWith('wss://speech.platform.bing.com/'));
      expect(url, contains('TrustedClientToken='));
      expect(url, contains('Sec-MS-GEC='));
      expect(url, contains('Sec-MS-GEC-Version='));
      expect(url, contains('ConnectionId=abc123'));
    });

    test('unreachable host fails within the 1.5s connect timeout', () async {
      final client = EdgeTtsClient(
        host: '127.0.0.1:1/consumer/speech/synthesize/readaloud/edge/v1',
        connectTimeout: const Duration(milliseconds: 1500),
      );
      final sw = Stopwatch()..start();
      await expectLater(client.synthesize('hello'), throwsA(isA<Object>()));
      sw.stop();
      expect(sw.elapsed, lessThan(const Duration(seconds: 3)));
    });
  });
}
