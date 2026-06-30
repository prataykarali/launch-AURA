part of '../input_bar.dart';

mixin _InputBarStateTyping on _InputBarStateBase {
  Future<void> _toggleMic() async {
    if (_isTranscribing) return;

    final stt = AuraSTTService.instance;
    if (stt.isListening) {
      setState(() {
        _isTranscribing = true;
      });
      final transcript = await stt.finalizeListening();
      setState(() {
        _isTranscribing = false;
      });
      if (transcript.isNotEmpty) {
        _ctrl.text = transcript;
        _submit(source: AuraObservationSource.speech);
      }
    } else {
      setState(() {
        _isTranscribing = false;
      });
      // Stop any ongoing reply speech before recording the user's voice so the
      // mic doesn't capture the previous answer and the new turn starts clean.
      await AuraTTSService.instance.stop();
      await Future.delayed(const Duration(milliseconds: 800));
      try {
        await stt.startListening(
          onResult: (text, isFinal) {
            _ctrl.text = text;
            _hasTextNotifier.value = text.trim().isNotEmpty;
          },
          onError: () {
            setState(() {
              _isTranscribing = false;
            });
          },
        );
      } catch (e) {
        debugPrint('STT Start Error: $e');
        setState(() {
          _isTranscribing = false;
        });
      }
    }
  }
}
