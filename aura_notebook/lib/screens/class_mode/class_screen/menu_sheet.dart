part of 'class_screen.dart';

class _MenuSheet extends StatelessWidget {
  final VoidCallback onSort, onFilter, onExport, onAbout;
  const _MenuSheet({
    required this.onSort,
    required this.onFilter,
    required this.onExport,
    required this.onAbout,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(
      bottom: MediaQuery.of(context).padding.bottom + 16,
    ),
    decoration: const BoxDecoration(
      color: _classSurfaceHigh,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        _MenuItem(Icons.sort_by_alpha_rounded, 'Sort A → Z', onSort),
        _MenuItem(Icons.filter_list_rounded, 'Filter by Subject', onFilter),
        _MenuItem(Icons.share_rounded, 'Share Class List', onExport),
        _MenuItem(Icons.info_outline_rounded, 'About ClassSync', onAbout),
        const SizedBox(height: 8),
      ],
    ),
  );
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: _classPrimary, size: 20),
    title: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
    onTap: onTap,
  );
}
