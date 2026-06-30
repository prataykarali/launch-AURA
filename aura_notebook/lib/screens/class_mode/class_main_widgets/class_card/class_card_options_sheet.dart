part of 'class_card.dart';

class _CardOptionsSheet extends StatelessWidget {
  final ClassData data;
  final String classCode;
  final VoidCallback onOpen, onShare;
  final VoidCallback? onDelete;
  const _CardOptionsSheet({
    required this.data,
    required this.classCode,
    required this.onOpen,
    required this.onShare,
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

        // Class header
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

        // Class code banner
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: data.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: data.color.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.key_rounded, color: data.accent, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CLASS CODE',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        classCode,
                        style: TextStyle(
                          color: data.accent,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                      Text(
                        'Share this code with students to join',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: classCode));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Code "$classCode" copied!'),
                        backgroundColor: const Color(0xFF1A1A2E),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: data.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: data.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Divider(color: Colors.white.withOpacity(0.06)),

        // Action buttons
        _SheetAction(
          Icons.open_in_new_rounded,
          'Open Class',
          data.accent,
          onOpen,
        ),
        _SheetAction(
          Icons.share_rounded,
          'Share Class Code',
          const Color(0xFF26A69A),
          onShare,
        ),
        if (onDelete != null)
          _SheetAction(
            Icons.delete_outline_rounded,
            'Delete Class',
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
