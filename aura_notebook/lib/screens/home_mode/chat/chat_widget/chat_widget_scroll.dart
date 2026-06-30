part of 'chat_widget.dart';

extension _AuraChatWidgetStateScroll on _AuraChatWidgetState {
  void _scheduleJump() {
    if (_jumpScheduled || !_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.maxScrollExtent - pos.pixels > 600) return;
    _jumpScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _jumpScheduled = false;
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }
}
