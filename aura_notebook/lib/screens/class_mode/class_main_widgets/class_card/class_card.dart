import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../class_pages/class_data.dart';

part 'class_card_colors.dart';
part 'class_card_header.dart';
part 'class_card_body.dart';
part 'class_card_options_sheet.dart';

class ClassCard extends StatefulWidget {
  final ClassData data;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  const ClassCard({super.key, required this.data, this.onTap, this.onDelete});
  @override
  State<ClassCard> createState() => _ClassCardState();
}

class _ClassCardState extends State<ClassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.975,
    ).animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _showOptions() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CardOptionsSheet(
        data: widget.data,
        onOpen: () {
          Navigator.pop(context);
          widget.onTap?.call();
        },
        onDelete: widget.onDelete == null
            ? null
            : () {
                Navigator.pop(context);
                widget.onDelete?.call();
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => _press.forward(),
        onTapUp: (_) {
          _press.reverse();
          widget.onTap?.call();
        },
        onTapCancel: () => _press.reverse(),
        onLongPress: _showOptions,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: d.accent.withOpacity(0.14),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(d: d, onOptions: _showOptions),
                _Body(d: d),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
