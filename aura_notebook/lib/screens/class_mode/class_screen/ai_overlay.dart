part of 'class_screen.dart';

class _AiOverlay extends StatelessWidget {
  final VoidCallback onClose;
  const _AiOverlay({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Material(
                    color: _classSurface.withOpacity(0.94),
                    elevation: 24,
                    shadowColor: Colors.black.withOpacity(0.45),
                    surfaceTintColor: _classPrimary.withOpacity(0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                      side: BorderSide(
                        color: Colors.white.withOpacity(0.12),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.58,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white.withOpacity(0.08),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: _classGold.withOpacity(0.14),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _classGold.withOpacity(0.28),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: _classGold,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  "Ask AURA",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                                const Spacer(),
                                IconButton.filledTonal(
                                  visualDensity: VisualDensity.compact,
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.08),
                                    foregroundColor: Colors.white70,
                                  ),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 22,
                                  ),
                                  onPressed: onClose,
                                ),
                              ],
                            ),
                          ),
                          const Expanded(child: AuraChatWidget()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
