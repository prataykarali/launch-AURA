part of 'vision_service.dart';

enum AuraVisionDeviceProfile {
  mobileMinimal,
  mobileFull,
  desktopMinimal,
  desktopFull,
}

class AuraVisionContext {
  const AuraVisionContext({
    required this.activity,
    this.detail,
    required this.stuck,
    required this.stuckDurationMins,
    required this.sourceTier,
    required this.deviceProfile,
    this.confidence = 0.0,
  });

  final String activity;
  final String? detail;
  final bool stuck;
  final int stuckDurationMins;
  final int sourceTier;
  final AuraVisionDeviceProfile deviceProfile;
  final double confidence;

  Map<String, Object?> toJson() => {
    'vision_context': {
      'activity': activity,
      if (detail != null && detail!.trim().isNotEmpty) 'detail': detail,
      'stuck': stuck,
      'stuck_duration_mins': stuckDurationMins,
      'source_tier': sourceTier,
      'device_profile': deviceProfile.name,
      'confidence': confidence,
    },
  };

  String get summary {
    final parts = [
      'activity=$activity',
      if (detail != null && detail!.trim().isNotEmpty) 'detail=$detail',
      if (stuck) 'stuck=${stuckDurationMins}m',
      'source_tier=$sourceTier',
      'device_profile=${deviceProfile.name}',
    ];
    return 'vision_context: ${parts.join("; ")}';
  }
}
