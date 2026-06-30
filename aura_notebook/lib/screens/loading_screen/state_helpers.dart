part of 'main.dart';

extension _LoadingScreenStateHelpers on _LoadingScreenState {
  void _setStep(_Step step) {
    if (!mounted) return;
    _updateState(() {
      _currentStep = step;
      _errorMsg = null;
      _progressTarget = _LoadingScreenState._stepProgress[step] ?? 0.0;
    });
    // Push model loading progress to AuraBar overlay
    AuraBarBrain.instance.showModelLoadingStatus(step.name);
  }

  void _setError(String msg) {
    if (!mounted) return;
    _updateState(() {
      _errorMsg = msg;
      _downloadProgress = null;
    });
    HapticFeedback.heavyImpact();
  }

  double get _effectiveProgress {
    if (_currentStep == _Step.download && _downloadProgress != null) {
      return 0.30 + (_downloadProgress! * 0.40);
    }
    // While auraInit is blocking on the real model warmup, show the live
    // creep instead of a frozen 0.90.
    if (_creeping) return _creepValue;
    return _progressTarget;
  }

  String get _statusLabel {
    if (_currentStep == _Step.download && _downloadProgress != null) {
      return 'Downloading... ${(_downloadProgress! * 100).toInt()}%';
    }
    return _LoadingScreenState._kStepLabels[_currentStep] ?? '';
  }
}
