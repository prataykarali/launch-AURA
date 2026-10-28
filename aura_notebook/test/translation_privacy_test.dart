import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura_notebook/services/preferences_service.dart';
import 'package:aura_notebook/services/translation_service/translation_service.dart';

/// HttpOverrides that records whether any HttpClient was created (i.e. any
/// attempt to reach the network). Every method throws if actually invoked so a
/// real connection can never slip through during the test.
class _RecordingHttpOverrides extends HttpOverrides {
  bool clientCreated = false;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clientCreated = true;
    throw StateError(
      'NETWORK EGRESS DETECTED: TranslationService attempted a network call '
      'while online translation was opted out.',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TranslationService privacy (opt-out is the default)', () {
    late _RecordingHttpOverrides overrides;

    setUp(() {
      overrides = _RecordingHttpOverrides();
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'non-English input triggers ZERO network calls when opted out',
      () async {
        // Default: no preference set == opted out.
        await HttpOverrides.runWithHttpOverrides(() async {
          // Devanagari text that "looksNonEnglish" and would previously have hit
          // Google Translate on every turn.
          final result = await TranslationService.instance.toEnglish(
            'नमस्ते दुनिया',
          );
          // Must resolve entirely offline.
          expect(result.source, isNot('google_translate'));
          expect(
            overrides.clientCreated,
            isFalse,
            reason: 'No HttpClient should be created when opted out',
          );
        }, overrides);
      },
    );

    test(
      'plain English input triggers ZERO network calls when opted out',
      () async {
        await HttpOverrides.runWithHttpOverrides(() async {
          final result = await TranslationService.instance.toEnglish(
            'hello world',
          );
          expect(result.source, 'offline_passthrough');
          expect(overrides.clientCreated, isFalse);
        }, overrides);
      },
    );

    test('online translation is OFF by default in preferences', () async {
      final enabled = await PreferencesService.instance
          .getOnlineTranslationEnabled();
      expect(
        enabled,
        isFalse,
        reason: 'Privacy default must be no network egress',
      );
    });
  });
}
