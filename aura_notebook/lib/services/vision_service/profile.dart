part of 'vision_service.dart';

AuraVisionDeviceProfile _deviceProfile() {
  final rss = ProcessInfo.currentRss;
  final processors = Platform.numberOfProcessors;
  final total =
      ResourceGuardService.instance.snapshotNotifier.value?.totalBytes;
  final totalGiB = total == null ? null : total / (1024 * 1024 * 1024);

  if (Platform.isAndroid || Platform.isIOS) {
    final mobileFull =
        processors >= 6 &&
        (totalGiB == null || totalGiB >= 6.0) &&
        rss < 3 * 1024 * 1024 * 1024;
    return mobileFull
        ? AuraVisionDeviceProfile.mobileFull
        : AuraVisionDeviceProfile.mobileMinimal;
  }

  final desktopFull =
      processors >= 8 && (totalGiB == null || totalGiB >= 12.0);
  return desktopFull
      ? AuraVisionDeviceProfile.desktopFull
      : AuraVisionDeviceProfile.desktopMinimal;
}

bool _canRunTier1For(AuraVisionDeviceProfile profile) =>
    profile != AuraVisionDeviceProfile.mobileMinimal;

bool _canRunTier2For(AuraVisionDeviceProfile profile) =>
    profile == AuraVisionDeviceProfile.desktopFull;

bool _canRunTier3For(AuraVisionDeviceProfile profile) =>
    profile == AuraVisionDeviceProfile.desktopMinimal ||
    profile == AuraVisionDeviceProfile.desktopFull;
