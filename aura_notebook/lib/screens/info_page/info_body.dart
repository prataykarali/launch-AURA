part of 'package:aura_notebook/screens/info_page.dart';

class _InfoBody extends StatelessWidget {
  final AnimationController orbCtrl;
  const _InfoBody({required this.orbCtrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A0A2E), Color(0xFF0A1A2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF7C4DFF).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              const Text(
                'AURA Device Status',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This page lists AURA credentials and the local features this '
                'build can use on the current device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),

        _Section('AURA CREDENTIALS', [
          _InfoTile(Icons.person_rounded, 'Developer', 'Pratay Karali'),
          _InfoTile(
            Icons.school_outlined,
            'Institute',
            'IEM Kolkata — CSE (AIML)',
          ),
          _InfoTile(Icons.badge_outlined, 'Enrollment', '12024002028038'),
          _InfoTile(
            Icons.tag_rounded,
            'Build',
            'AURA local notebook companion',
          ),
        ]),

        const SizedBox(height: 20),

        _Section('DEVICE', [
          _InfoTile(
            Platform.isAndroid ? Icons.phone_android_rounded : Icons.computer_rounded,
            'Platform',
            Platform.isAndroid ? 'Android (overlay mode)' : 'Linux (desktop mode)',
          ),
          _InfoTile(
            Icons.smart_toy_outlined,
            'Local LLM',
            'On-device chat and memory. No cloud required.',
          ),
          _InfoTile(
            Icons.memory_rounded,
            'Memory',
            'Profile stores explicit facts about the user. Summaries keep a rolling recap of recent conversations.',
          ),
          _InfoTile(
            Icons.event_note_rounded,
            'Notes',
            'Stores user notes, proactive schedule notes, and vision observations. Deleted notes are hidden from recall.',
          ),
          _InfoTile(
            Icons.visibility_rounded,
            'Vision',
            Platform.isAndroid
                ? 'Camera observations are saved as Notes when permissions and assets are available.'
                : 'Webcam + screen context are saved as Notes when camera/assets are available.',
          ),
          _InfoTile(
            Icons.record_voice_over_rounded,
            'Voice',
            Platform.isAndroid
                ? 'Android system speech-to-text and text-to-speech engines.'
                : 'Rust sherpa-onnx STT/TTS (offline Piper voice) plus the Whisper server.',
          ),
          _InfoTile(
            Icons.window_outlined,
            'UI',
            Platform.isAndroid
                ? 'Android overlay interface. The floating desktop bar is only available on Linux.'
                : 'Floating desktop bar and multi-window overlay.',
          ),
        ]),

        const SizedBox(height: 20),

        _Section('DEVICE RESTRICTIONS', [
          _InfoTile(
            Icons.memory_rounded,
            'Memory pressure',
            Platform.isAndroid
                ? 'If the device is low on memory, AURA may throttle vision, proactive work, and extra senses to stay stable.'
                : 'If your laptop memory is almost full, AURA pauses extra senses and shows: "Close something heavy, then try again."',
          ),
          _InfoTile(
            Icons.thermostat_rounded,
            'Cooldown',
            'If AURA is running hot, it pauses itself to stay stable and shows: "AURA is cooling down. Close something heavy, then try again."',
          ),
          _InfoTile(
            Icons.timer_outlined,
            'Slow replies',
            Platform.isAndroid
                ? 'On Android the model runs on the CPU. Complex or memory-heavy questions may take up to 10 seconds; very slow generations are cancelled and a safe fallback is shown.'
                : 'On slower Linux machines, heavy context or vision can take a few seconds. The bar has a 10-second safety timeout.',
          ),
          if (Platform.isAndroid)
            _InfoTile(
              Icons.warning_amber_rounded,
              'No Rust voice stack',
              'sherpa-onnx is not built for Android, so AURA uses the system TTS/STT engines instead of the offline Rust voice engine.',
            ),
        ]),
      ],
    );
  }
}
