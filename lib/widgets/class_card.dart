import 'package:flutter/material.dart';
import '../screens/class_data.dart';

class ClassCard extends StatefulWidget {
  final ClassData  data;
  final VoidCallback? onTap;
  const ClassCard({super.key, required this.data, this.onTap});
  @override
  State<ClassCard> createState() => _ClassCardState();
}

class _ClassCardState extends State<ClassCard>
    with SingleTickerProviderStateMixin {

  late final AnimationController _press;
  late final Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.975)
        .animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));
  }

  @override
  void dispose() { _press.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown:   (_) => _press.forward(),
        onTapUp:     (_) { _press.reverse(); widget.onTap?.call(); },
        onTapCancel: ()  => _press.reverse(),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color:      d.color.withOpacity(0.30),
                blurRadius: 24, offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(d: d),
                _Body(d: d),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final ClassData d;
  const _Header({required this.d});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            d.color,
            Color.lerp(d.color, Colors.black, 0.25)!,
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(d.subject.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 9.5, fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                // Name
                Text(d.name,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.w800, height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                // Section
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 12, color: Colors.white.withOpacity(0.55)),
                    const SizedBox(width: 4),
                    Text(d.section,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.65), fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Icon badge
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.16),
              border: Border.all(
                  color: Colors.white.withOpacity(0.28), width: 1.5),
            ),
            child: Icon(d.icon, color: Colors.white, size: 24),
          ),
        ],
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────
class _Body extends StatelessWidget {
  final ClassData d;
  const _Body({required this.d});

  String get _initial =>
      d.teacher.trim().split(' ').last.substring(0, 1).toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161625),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stats strip
          Container(
            color: const Color(0xFF0F0F1E),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            child: Row(
              children: [
                _Stat(Icons.people_outline_rounded,
                    '${d.students} students', d.accent),
                const SizedBox(width: 16),
                _Stat(Icons.assignment_outlined, 'Assignments', d.accent),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: d.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: d.accent.withOpacity(0.3)),
                  ),
                  child: Text('Active',
                    style: TextStyle(
                      color: d.accent, fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Teacher row
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [d.accent, d.color],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(_initial,
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.teacher,
                          style: const TextStyle(color: Colors.white,
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('Class Teacher',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.38),
                              fontSize: 11)),
                    ],
                  ),
                ),
                // Tap to open hint
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: d.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: d.color.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Open',
                          style: TextStyle(color: d.accent, fontSize: 11,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded,
                          size: 10, color: d.accent),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Divider(height: 1, color: Colors.white.withOpacity(0.06)),

          // Quick action row
          IntrinsicHeight(
            child: Row(
              children: [
                _QA(Icons.menu_book_outlined,        'Lessons',   d.accent),
                _VDiv(),
                _QA(Icons.people_outline_rounded,    'Students',  d.accent),
                _VDiv(),
                _QA(Icons.assignment_outlined,       'Tasks',     d.accent),
                _VDiv(),
                _QA(Icons.campaign_outlined,         'Stream',    d.accent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _Stat(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: color.withOpacity(0.7)),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.45),
          fontSize: 11)),
    ],
  );
}

class _QA extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _QA(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(color: Colors.white.withOpacity(0.4),
                    fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
          ],
        ),
      ),
    ),
  );
}

class _VDiv extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      VerticalDivider(width: 1, color: Colors.white.withOpacity(0.06));
}