import 'dart:async';
import 'package:flutter/material.dart';
import 'package:aura_notebook/src/rust/api.dart';
import 'chat_constants.dart';
import '../../../services/bar_brain.dart';
import '../../../services/natural_context_service.dart';
import '../../../services/stt_service.dart';
import '../../../services/tts_service.dart';

part 'input_bar/input_bar_state.dart';
part 'input_bar/input_bar_typing.dart';

// ─── Prefill gate ─────────────────────────────────────────────────────────────
//
// Mirrors the Thread A sliding-window gate in prefill.rs:
//   • At least kMinWordsForPrefill words
//   • Ends on a word boundary (last char is alphanumeric or common punctuation)
//   • Not a duplicate of the last successfully prefilled string
//
bool _passesPrefillGate(String text, String lastPrefilled) {
  if (text == lastPrefilled) return false;

  // Word count gate
  final wordCount = text
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .length;
  if (wordCount < kMinWordsForPrefill) return false;

  // Word-boundary end: last non-space char must be alphanumeric or end-of-sentence
  final lastChar = text.trimRight().isEmpty
      ? ''
      : text.trimRight()[text.trimRight().length - 1];
  final isWordBoundary = RegExp(r"[a-zA-Z0-9.!?,']").hasMatch(lastChar);
  if (!isWordBoundary) return false;

  return true;
}

// ─── InputBar widget ──────────────────────────────────────────────────────────

class InputBar extends StatefulWidget {
  final Future<void> Function(String, {AuraObservationSource source}) onSend;
  final VoidCallback onStop;
  final ValueNotifier<bool> busy;

  const InputBar({
    super.key,
    required this.onSend,
    required this.onStop,
    required this.busy,
  });

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends _InputBarStateBase with _InputBarStateTyping {
  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: widget.busy,
    builder: (_, isBusy, __) => Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.indigo.withOpacity(0.08),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
            // Subtle active-typing glow: shows user + Rust are in sync
            if (_isActivelyTyping && !isBusy)
              BoxShadow(
                color: Colors.indigoAccent.withOpacity(0.18),
                blurRadius: 22,
                spreadRadius: 2,
              ),
          ],
        ),
        child: Row(
          children: [
            if (!isBusy)
              ValueListenableBuilder<bool>(
                valueListenable: AuraSTTService.instance.isListeningNotifier,
                builder: (context, isListening, _) {
                  if (_isTranscribing) {
                    return const Padding(
                      padding: EdgeInsets.only(left: 14, right: 2),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.indigoAccent,
                          ),
                        ),
                      ),
                    );
                  }
                  return GestureDetector(
                    onTap: _toggleMic,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 14, right: 2),
                      child: Icon(
                        isListening
                            ? Icons.stop_circle_rounded
                            : Icons.mic_rounded,
                        color: isListening
                            ? Colors.redAccent
                            : Colors.indigoAccent,
                        size: 22,
                      ),
                    ),
                  );
                },
              ),
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                // Always enabled — user can type the next question while AURA
                // is generating. The send button is replaced by a Stop button
                // during inference, so submitting early is guarded there.
                onSubmitted: (_) => !isBusy ? _submit() : null,
                textInputAction: TextInputAction.send,
                enableSuggestions: false,
                autocorrect: false,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontSize: 15, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Talk to AURA...',
                  hintStyle: const TextStyle(
                    color: Colors.black38,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.fromLTRB(
                    isBusy ? 20 : 8,
                    15,
                    16,
                    15,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              // The send button listens to _hasTextNotifier so it only rebuilds
              // on empty↔non-empty transitions — NOT on every keystroke. This is
              // the send-button half of the typing-freeze fix.
              child: ValueListenableBuilder<bool>(
                valueListenable: _hasTextNotifier,
                builder: (_, hasText, __) => GestureDetector(
                  onTap: isBusy ? widget.onStop : (hasText ? _submit : null),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isBusy
                          ? Colors.redAccent
                          : (hasText
                                ? Colors.indigoAccent
                                : Colors.indigo.shade100),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      isBusy ? Icons.stop_rounded : Icons.send_rounded,
                      color: (isBusy || hasText)
                          ? Colors.white
                          : Colors.indigo.shade300,
                      size: isBusy ? 22 : 18,
                    ),
                  ),
                ),
              ),
            ), // close inner Padding (send-button wrapper)
          ],
        ),
      ),
    ),
  );
}
