part of 'chat_widget.dart';

String _sanitizeText(String text, String prompt) {
  var cleaned = text;

  // 1. Strip  <think>... </think> (if not closed yet)
  if (cleaned.contains('<think>')) {
    final openIdx = cleaned.indexOf('<think>');
    final closeIdx = cleaned.indexOf('</think>');
    if (closeIdx != -1) {
      cleaned =
          cleaned.substring(0, openIdx) + cleaned.substring(closeIdx + 8);
    } else {
      cleaned = cleaned.substring(0, openIdx);
    }
  }

  // 2. Strip speaker labels / prompt echoes
  final promptTrimmed = prompt.trim();
  final directivePatterns = [
    RegExp(r'^\s*(?:User|AURA|Assistant|System):\s*', caseSensitive: false),
  ];

  var changed = true;
  while (changed) {
    changed = false;
    final trimmedCleaned = cleaned.trimLeft();
    if (promptTrimmed.isNotEmpty &&
        trimmedCleaned.toLowerCase().startsWith(
          promptTrimmed.toLowerCase(),
        )) {
      final leadingWhitespace = cleaned.length - trimmedCleaned.length;
      final start = leadingWhitespace + promptTrimmed.length;
      if (cleaned.length > start) {
        cleaned = cleaned.substring(start);
        changed = true;
      } else {
        cleaned = '';
        break;
      }
    }
    for (final pattern in directivePatterns) {
      final next = cleaned.replaceFirst(pattern, '');
      if (next != cleaned) {
        cleaned = next;
        changed = true;
      }
    }
  }

  return cleaned;
}

// ── Typewriter Logic ──────────────────────────────────────────────────────

extension _AuraChatWidgetStateTypewriter on _AuraChatWidgetState {
  void _startTypewriter({required bool isThinkingPhase}) {
    _typewriterTimer?.cancel();
    final interval = isThinkingPhase
        ? const Duration(milliseconds: 30)
        : const Duration(milliseconds: 15);

    _typewriterTimer = Timer.periodic(interval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (isThinkingPhase) {
        // Just wait for the first real token. If the stream closes without
        // sending any real token, commit a fallback so the UI never gets stuck
        // on the thinking indicator.
        if (_generationFinished) {
          timer.cancel();
          _forceCompleteTypewriter(
            _generationBuffer.isNotEmpty
                ? _generationBuffer.toString()
                : '⚠️ No response.',
          );
        }
        return;
      }

      final sanitized = _sanitizeText(
        _generationBuffer.toString(),
        _currentPrompt,
      );
      if (_displayedBuffer.length < sanitized.length) {
        int charsToPop = 1;
        // Dynamic catching up during generation phase
        final diff = sanitized.length - _displayedBuffer.length;
        if (diff > 80) {
          charsToPop = 15;
        } else if (diff > 40) {
          charsToPop = 8;
        } else if (diff > 20) {
          charsToPop = 4;
        } else if (diff > 10) {
          charsToPop = 2;
        }

        final nextLength = (_displayedBuffer.length + charsToPop).clamp(
          0,
          sanitized.length,
        );
        _displayedBuffer.clear();
        _displayedBuffer.write(sanitized.substring(0, nextLength));
        _streamText.value = '$_displayedBuffer▍';
        _scheduleJump();
      } else {
        if (_generationFinished) {
          timer.cancel();
          _commitBubble(_displayedBuffer.toString());
        }
      }
    });
  }

  void _forceCompleteTypewriter(String fallback) {
    _typewriterTimer?.cancel();
    final textToCommit = _displayedBuffer.isNotEmpty
        ? _displayedBuffer.toString()
        : fallback;
    _commitBubble(textToCommit);
  }
}
