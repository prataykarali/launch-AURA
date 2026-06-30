part of 'aura_bar_lib.dart';

void _runTypewriter(
  _AuraBarState state,
  String fullText,
  void Function(VoidCallback) setState,
) {
  const kMaxDisplay = 100;
  final sanitized = _safeUiText(fullText);
  final chars = sanitized.characters;
  final displayText = chars.length > kMaxDisplay
      ? '…${chars.skip(chars.length - kMaxDisplay).toString()}'
      : sanitized;

  if (displayText.startsWith(state._displayedMessage) &&
      state._displayedMessage.isNotEmpty) {
    final newPart = displayText.substring(state._displayedMessage.length);
    if (state._typewriterQueue.length < 200) {
      state._typewriterQueue.addAll(newPart.characters);
    }
  } else if (state._displayedMessage.isNotEmpty) {
    state._displayedMessage = displayText;
    state._typewriterQueue.clear();
  } else {
    state._displayedMessage = '';
    state._typewriterQueue.clear();
    state._typewriterQueue.addAll(displayText.characters);
  }

  state._typewriterTimer?.cancel();
  state._typewriterTimer = Timer.periodic(const Duration(milliseconds: 18), (
    timer,
  ) {
    if (!state.mounted) {
      timer.cancel();
      return;
    }
    if (state._typewriterQueue.isNotEmpty) {
      int charsToPop = 1;
      if (state._typewriterQueue.length > 80)
        charsToPop = 15;
      else if (state._typewriterQueue.length > 40)
        charsToPop = 8;
      else if (state._typewriterQueue.length > 15) charsToPop = 3;

      setState(() {
        for (int i = 0;
            i < charsToPop && state._typewriterQueue.isNotEmpty;
            i++) {
          state._displayedMessage += state._typewriterQueue.removeAt(0);
        }
        final shownChars = state._displayedMessage.characters;
        if (shownChars.length > kMaxDisplay + 10) {
          state._displayedMessage =
              '…${shownChars.skip(shownChars.length - kMaxDisplay).toString()}';
          state._typewriterQueue.clear();
        }
      });
    } else {
      timer.cancel();
    }
  });
}

String _safeUiText(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final isControl = rune < 0x20 && rune != 0x09 && rune != 0x0A;
    final isReplacement = rune == 0xFFFD;
    if (!isControl && !isReplacement) {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}
