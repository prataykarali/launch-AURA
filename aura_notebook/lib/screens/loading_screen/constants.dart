part of 'main.dart';

const _kModelFilename = 'LFM2.5-1.2B-Instruct-Q4_K_M.gguf';
const _kTokenizerFilename = 'tokenizer.json';
const _kEmbedFilename = 'bge_model.onnx';
const _kEmbedTokFilename = 'bge_tokenizer.json';

const _kModelAssetPath = 'assets/LFM2.5-1.2B-Instruct-Q4_K_M.gguf';
const _kTokenizerAssetPath = 'assets/tokenizer.json';
const _kEmbedAssetPath = 'assets/embedder/model_quantized.onnx';
const _kEmbedTokAssetPath = 'assets/embedder/tokenizer.json';

// ── GGUF delivery strategy ──────────────────────────────────────────────────
// The chat model is NOT bundled in the APK (see pubspec.yaml): baking it
// in produced a very large APK. Instead:
//  • Desktop: read it directly from the bundle / source assets dir at runtime
//    (same candidate-walk pattern tts_service.dart uses for piper).
//  • Android: download it ONCE to app-docs on the loading screen, then reuse.
const _kModelUrl =
    'https://huggingface.co/LiquidAI/LFM2.5-1.2B-GGUF/resolve/main/LFM2.5-1.2B-Instruct-Q4_K_M.gguf';
// Embedder URL — upload model_quantized.onnx + tokenizer.json to the same repo.
// If empty, Android will skip the embedder (semantic memory disabled, chat still works).
const _kEmbedModelUrl =
    'https://huggingface.co/Xenova/bge-small-en-v1.5/resolve/main/onnx/model.onnx';
const _kEmbedTokUrl =
    'https://huggingface.co/Xenova/bge-small-en-v1.5/resolve/main/tokenizer.json';
// Min file sizes we accept as "complete".
const int _kModelMinBytes = 400 * 1024 * 1024; // LFM2.5 1.2B Q4_K_M ~698 MB
const int _kEmbedMinBytes =
    20 * 1024 * 1024; // BGE small fp32 ~44 MB (model.onnx)
const _kOldModelSuffixes = ['.kvcache', '.kvcache.pos', '.memory.db'];

// Total space AURA needs for the chat model + embedder (for error display).
// Kept lean so the bar stays open on tighter storage — the model itself is
// already on disk after first run, so this only gates the first-download hint.
const int _kTotalNeededBytes =
    _kModelMinBytes + _kEmbedMinBytes + (10 * 1024 * 1024);

const _kQuotes = [
  'AURA is always by your side! 💖',
  'When its time for adventure count on me! 🚀',
  'Heads up traveller! Lets get started! ✨',
  'Lets have some free time together... 🎮',
  'A companion whos always there to be with you! 🌟',
  'I\'ve learned some new tricks! Like using Selenium... 🤖',
  'Automating your world, one task at a time! 🛠️',
  'Ask me anything about your classes or notebook! 📚',
];

enum _Step { wake, check, prepare, download, embed, engine, services, ready }

class _ReadinessState {
  bool model = false;
  bool memory = false;
  bool tts = false;
  bool stt = false;
  bool characterAssets = false;
  bool backend = false;
  bool platformServices = false;

  // Only model + memory + backend are REQUIRED for the app to function.
  // STT, TTS, characterAssets, and platformServices are optional — the app
  // works in text-only mode without them. Blocking startup on optional
  // subsystems caused the app to show an error and refuse to load whenever
  // the TTS engine was slow to warm up or the STT permission was denied.
  bool get allReady => model && memory && backend;

  // Required subsystems only — shown in the error message when startup fails.
  List<String> get missing {
    final items = <String>[];
    if (!model) items.add('model');
    if (!memory) items.add('memory');
    if (!backend) items.add('backend');
    return items;
  }

  // Optional subsystems — logged as warnings but do NOT block startup.
  List<String> get warnings {
    final items = <String>[];
    if (!tts) items.add('tts (text-only mode)');
    if (!stt) items.add('stt (type-only input)');
    if (!characterAssets) items.add('character assets');
    if (!platformServices) items.add('platform overlay');
    return items;
  }
}

// Model path bundle returned by the platform-specific loaders.
typedef _ModelPaths = ({
  String modelPath,
  String tokPath,
  String embedPath,
  String embedTokPath,
});
