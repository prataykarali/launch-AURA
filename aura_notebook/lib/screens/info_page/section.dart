part of 'package:aura_notebook/screens/info_page.dart';

class _Section extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _Section(this.label, this.children);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.28),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
      ),
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF161625),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          children: children
              .asMap()
              .entries
              .map(
                (e) => Column(
                  children: [
                    e.value,
                    if (e.key < children.length - 1)
                      Divider(
                        height: 1,
                        indent: 54,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    ],
  );
}
