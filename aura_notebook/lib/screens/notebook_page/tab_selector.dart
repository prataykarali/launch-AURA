import 'package:flutter/material.dart';

class TabSelector extends StatelessWidget {
  final int activeTab;
  final ValueChanged<int> onTabChanged;

  const TabSelector({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          TabButton(
            index: 0,
            label: '📚 Turns',
            icon: Icons.chat_bubble_outline_rounded,
            activeTab: activeTab,
            onTap: onTabChanged,
          ),
          TabButton(
            index: 1,
            label: '📝 Summaries',
            icon: Icons.auto_awesome_outlined,
            activeTab: activeTab,
            onTap: onTabChanged,
          ),
          TabButton(
            index: 2,
            label: '💡 Profile',
            icon: Icons.face_retouching_natural_rounded,
            activeTab: activeTab,
            onTap: onTabChanged,
          ),
          TabButton(
            index: 3,
            label: '🗒️ Notes',
            icon: Icons.sticky_note_2_outlined,
            activeTab: activeTab,
            onTap: onTabChanged,
          ),
        ],
      ),
    );
  }
}

class TabButton extends StatelessWidget {
  final int index;
  final String label;
  final IconData icon;
  final int activeTab;
  final ValueChanged<int> onTap;

  const TabButton({
    super.key,
    required this.index,
    required this.label,
    required this.icon,
    required this.activeTab,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.indigo.shade50 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.indigo.shade800 : Colors.black45,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.indigo.shade800 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
