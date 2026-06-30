#!/usr/bin/env python3
"""
AURA Whisper STT Server
=======================
Persistent process that loads multilingual whisper-base once on GPU, then serves
transcription requests from Flutter via stdin/stdout.

Protocol (line-delimited, UTF-8):
  ← Flutter sends:  <absolute_path_to_wav_file>\n
  → Server replies: RESULT:<transcription_text>\n
                 or ERROR:<message>\n
                 or READY\n  (on startup, model loaded)

The model stays loaded in GPU VRAM between requests — no per-request
load overhead. Transcription of 5–10s of speech takes ~0.3–0.8s on RTX 2050.
"""

import sys
import os
import traceback

def main():
    # Flush all output immediately so Flutter gets READY without buffering.
    sys.stdout.reconfigure(line_buffering=True)
    sys.stderr.reconfigure(line_buffering=True)

    # Automatically terminate process if parent exits (Linux only)
    if sys.platform.startswith('linux'):
        try:
            import ctypes
            libc = ctypes.CDLL("libc.so.6")
            # PR_SET_PDEATHSIG = 1, SIGKILL = 9
            libc.prctl(1, 9, 0, 0, 0)
        except Exception:
            pass

    model_name = os.environ.get("AURA_WHISPER_MODEL", "base")

    try:
        import whisper
        import numpy as np
        import soundfile as sf
        import torch
    except ImportError as e:
        print(f"ERROR:Missing dependency: {e}. Install: pip install openai-whisper soundfile torch", flush=True)
        sys.exit(1)

    device = "cuda" if torch.cuda.is_available() else "cpu"
    global fp16_flag
    fp16_flag = (device == "cuda")

    try:
        model = whisper.load_model(model_name, device=device)
        print("READY", flush=True)
    except Exception as e:
        print(f"ERROR:Failed to load whisper model '{model_name}' on device '{device}': {e}", flush=True)
        sys.exit(1)

    # Main request loop
    for line in sys.stdin:
        wav_path = line.strip()
        if not wav_path:
            continue
        if not os.path.isfile(wav_path):
            print(f"ERROR:File not found: {wav_path}", flush=True)
            continue

        try:
            # Load WAV — soundfile handles any PCM WAV whisper can process.
            audio, sr = sf.read(wav_path, dtype="float32", always_2d=False)
            # Whisper expects mono 16 kHz. Resample if needed (arecord gives 16k already).
            if sr != 16000:
                import resampy
                audio = resampy.resample(audio, sr, 16000)

            # Run inference with language auto-detection so AURA can understand
            # multilingual speech, then Dart translates the transcript to English.
            # condition_on_previous_text=False avoids hallucinating filler based
            # on prior context when audio is short/silent.
            # beam_size=1 for fastest greedy decoding. best_of=1 disables beam search.
            result = model.transcribe(
                audio,
                fp16=fp16_flag,                    # GPU half-precision: ~2x faster
                condition_on_previous_text=False,
                no_speech_threshold=0.6,      # discard segments with low speech probability
                logprob_threshold=-1.0,       # discard very uncertain tokens
                compression_ratio_threshold=2.4,
                temperature=0.0,              # greedy decoding = deterministic
                beam_size=1,                  # single beam = fastest
                best_of=1,                    # no beam search
                patience=1.0,                 # no early stopping wait
                word_timestamps=False,        # skip word-level timing
                prepend_punctuations="\"'¿([{-",
                append_punctuations="\"'.。,，!！?？:：\")]}、",
            )
            text = result["text"].strip()
            # Clean up any leading/trailing punctuation artifacts whisper adds.
            text = text.strip(".,!? \t\n")
            print(f"RESULT:{text}", flush=True)
        except Exception as e:
            tb = traceback.format_exc().replace("\n", " | ")
            print(f"ERROR:Transcription failed: {e} | {tb}", flush=True)

if __name__ == "__main__":
    main()
