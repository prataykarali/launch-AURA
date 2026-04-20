// Place at: lib/screens/detail_widgets/empty_state.dart
import 'package:flutter/material.dart';

/// Reusable empty state used across all tabs.
/// Pass [imagePath] to show an illustration, or [icon] for a fallback icon.
///
/// IMAGE PLACEHOLDERS summary:
///   • Assets/images/empty_lessons.png    → LessonsTab
///   • Assets/images/empty_resources.png  → ResourcesTab
///   • Assets/images/empty_students.png   → StudentsTab
///
/// Recommended size: 300×250 px, transparent background PNG
/// Style: flat/cartoon illustration, matches dark theme with muted colours
class EmptyState extends StatelessWidget {
  final String? imagePath;
  final String title, subtitle;
  final Color accent;
  final IconData? icon;
  final Widget? action;

  const EmptyState({
    super.key,
    this.imagePath,
    required this.title,
    required this.subtitle,
    required this.accent,
    this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // Illustration or icon
          if (imagePath != null)
            Image.asset(
              imagePath!,
              height: 160,
              fit: BoxFit.contain,
              // Falls back to icon if image not found
              errorBuilder: (_, __, ___) => _FallbackIcon(
                  icon: icon ?? Icons.inbox_outlined, color: accent),
            )
          else
            _FallbackIcon(icon: icon ?? Icons.inbox_outlined, color: accent),

          const SizedBox(height: 20),

          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.38),
                  fontSize: 13, height: 1.5)),

          if (action != null) ...[
            const SizedBox(height: 20),
            action!,
          ],
        ],
      ),
    ),
  );
}

class _FallbackIcon extends StatelessWidget {
  final IconData icon; final Color color;
  const _FallbackIcon({required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 80, height: 80,
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      shape: BoxShape.circle,
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Icon(icon, size: 36, color: color.withOpacity(0.5)),
  );
}