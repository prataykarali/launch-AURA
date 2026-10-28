part of 'class_card.dart';

class _CardOptionsSheet extends StatelessWidget {
  final ClassData data;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;
  const _CardOptionsSheet({
    required this.data,
    required this.onOpen,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(
      bottom: MediaQuery.of(context).padding.bottom + 20,
    ),
    decoration: BoxDecoration(
      color: _cardSurface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      border: Border(
        top: BorderSide(color: data.accent.withOpacity(0.3)),
        left: BorderSide(color: data.accent.withOpacity(0.1)),
        right: BorderSide(color: data.accent.withOpacity(0.1)),
      ),
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

        // Course header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(data.icon, color: data.accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      data.section,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Divider(color: Colors.white.withOpacity(0.06)),

        // Action buttons
        _SheetAction(
          Icons.menu_book_rounded,
          'Open Notes & Study Hub',
          data.accent,
          onOpen,
        ),
        if (onDelete != null)
          _SheetAction(
            Icons.delete_outline_rounded,
            'Delete Course',
            Colors.redAccent,
            onDelete!,
          ),
      ],
    ),
  );
}

class _SheetAction extends StatelessWidget {
  final IconData i;
  final String l;
  final Color c;
  final VoidCallback onTap;
  const _SheetAction(this.i, this.l, this.c, this.onTap);
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(i, color: c, size: 18),
    ),
    title: Text(
      l,
      style: TextStyle(
        color: c == Colors.redAccent ? Colors.redAccent : Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    ),
    onTap: onTap,
  );
}
