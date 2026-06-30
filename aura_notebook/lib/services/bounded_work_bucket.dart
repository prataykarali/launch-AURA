import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

typedef BucketWorker<T> = FutureOr<void> Function(T item);

/// Small bounded FIFO for sensory work.
///
/// `tryAdd` is deliberately non-blocking. When the bucket is full the new item
/// is rejected, so camera/audio producers cannot build an unbounded backlog on
/// the UI isolate.
class BoundedWorkBucket<T> {
  BoundedWorkBucket({required this.name, required this.capacity})
    : assert(capacity > 0);

  final String name;
  final int capacity;
  final Queue<T> _queue = Queue<T>();

  bool _draining = false;
  int _dropped = 0;

  int get length => _queue.length;
  int get dropped => _dropped;
  bool get isFull => _queue.length >= capacity;

  bool tryAdd(T item, BucketWorker<T> worker) {
    if (isFull) {
      _dropped++;
      if (_dropped == 1 || _dropped % 10 == 0) {
        debugPrint(
          '[AURA_BUCKET] $name full ($capacity) — dropped $_dropped item(s)',
        );
      }
      return false;
    }

    _queue.addLast(item);
    _drain(worker);
    return true;
  }

  bool addLatest(T item, BucketWorker<T> worker) {
    while (isFull && _queue.isNotEmpty) {
      _queue.removeFirst();
      _dropped++;
    }

    _queue.addLast(item);
    _drain(worker);
    return true;
  }

  void clear() {
    _queue.clear();
  }

  void _drain(BucketWorker<T> worker) {
    if (_draining) return;
    _draining = true;

    scheduleMicrotask(() async {
      try {
        while (_queue.isNotEmpty) {
          final item = _queue.removeFirst();
          await worker(item);
        }
      } catch (e, st) {
        debugPrint('[AURA_BUCKET] $name worker error: $e\n$st');
      } finally {
        _draining = false;
        if (_queue.isNotEmpty) {
          _drain(worker);
        }
      }
    });
  }
}
