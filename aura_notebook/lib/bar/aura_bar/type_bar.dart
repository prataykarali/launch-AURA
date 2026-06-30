part of 'aura_bar_lib.dart';

Widget _buildTypeBar(_AuraBarState state) {
  return Container(
    height: 38,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Row(
      children: [
        const Icon(Icons.keyboard_rounded, color: Colors.white38, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: state._textCtrl,
            focusNode: state._focusNode,
            autofocus: false,
            enableInteractiveSelection: true,
            enableSuggestions: true,
            autocorrect: true,
            maxLength: kBarMaxChars,
            inputFormatters: [LengthLimitingTextInputFormatter(kBarMaxChars)],
            style: const TextStyle(color: Colors.white, fontSize: 13),
            cursorColor: const Color(0xFFFF9CEE),
            cursorWidth: 2,
            cursorHeight: 18,
            buildCounter:
                (
                  _, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => const SizedBox.shrink(),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              counterText: '',
              hintText: state.widget.state == BarState.proactive
                  ? "Type a reply..."
                  : "Ask AURA anything...",
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 13,
              ),
            ),
            onSubmitted: (val) {
              if (val.trim().isNotEmpty) {
                if (state.widget.onSubmitText != null) {
                  state.widget.onSubmitText!(val.trim());
                }
                state._textCtrl.clear();
                state._focusNode.unfocus();
              }
            },
            onTapOutside: (event) {
              // Don't auto-unfocus on tap outside - let user control focus
            },
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: state._barHasTextNotifier,
          builder: (_, hasText, __) {
            if (!hasText) return const SizedBox.shrink();
            final len = state._textCtrl.text.length;
            if (len < kBarMaxChars - 30) return const SizedBox(width: 6);
            final danger = len > kBarMaxChars - 15;
            return Padding(
              padding: const EdgeInsets.only(left: 4, right: 4),
              child: Text(
                '$len/$kBarMaxChars',
                style: TextStyle(
                  color: danger
                      ? const Color(0xFFFF6B6B)
                      : Colors.white.withOpacity(0.45),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: state._barHasTextNotifier,
          builder: (_, hasText, __) {
            if (!hasText) return const SizedBox.shrink();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    final val = state._textCtrl.text.trim();
                    if (val.isNotEmpty) {
                      if (state.widget.onSubmitText != null) {
                        state.widget.onSubmitText!(val);
                      }
                      state._textCtrl.clear();
                      state._focusNode.unfocus();
                    }
                  },
                  child: const Icon(
                    Icons.send_rounded,
                    color: Color(0xFFFF9CEE),
                    size: 16,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
