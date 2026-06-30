part of 'class_card.dart';

class _Header extends StatelessWidget {
  final ClassData d;
  final String classCode;
  final VoidCallback onOptions;
  const _Header({
    required this.d,
    required this.classCode,
    required this.onOptions,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Color.lerp(d.color, Colors.white, 0.10)!,
          Color.lerp(d.color, _cardSurfaceLow, 0.24)!,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subject badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                margin: const EdgeInsets.only(bottom: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  d.subject.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Text(
                d.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 12,
                    color: Colors.white.withOpacity(0.55),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    d.section,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          children: [
            // Icon badge
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.28),
                  width: 1.5,
                ),
              ),
              child: Icon(d.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 8),
            // Options button (⋮)
            GestureDetector(
              onTap: onOptions,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
