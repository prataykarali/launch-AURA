#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
FRB = ROOT / "src" / "frb_generated.rs"


def strip_block(text: str, start: str, end: str) -> str:
    pattern = re.compile(re.escape(start) + r".*?" + re.escape(end), re.S)
    return pattern.sub("", text)


def main() -> int:
    text = FRB.read_text()

    # Remove the invalid str auto-opaque bridge artifacts emitted by FRB.
    text = re.sub(
        r"flutter_rust_bridge::frb_generated_moi_arc_impl_value!\(\s*"
        r"flutter_rust_bridge::for_generated::RustAutoOpaqueInner<str>\s*\);\s*",
        "",
        text,
    )
    text = strip_block(
        text,
        "impl SseDecode for RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<str>> {",
        "}\n\nimpl SseDecode for StreamSink<String, flutter_rust_bridge::for_generated::SseCodec>",
    )
    text = strip_block(
        text,
        "impl SseEncode for RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<str>> {",
        "}\n\nimpl SseEncode for StreamSink<String, flutter_rust_bridge::for_generated::SseCodec>",
    )
    text = strip_block(
        text,
        "impl SseDecode\n    for Option<RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<str>>>\n{",
        "}\n\nimpl SseDecode for Option<crate::api::tts::TtsAudio>",
    )
    text = strip_block(
        text,
        "impl SseEncode\n    for Option<RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<str>>>\n{",
        "}\n\nimpl SseEncode for Vec<crate::vision::events::VisionDetection>",
    )

    # Drop the WASM strong-count exports for str.
    text = re.sub(
        r"\n\s*pub extern \"C\" fn frbgen_aura_notebook_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerstr\([\s\S]*?\n\s*}\n\s*\n\s*pub extern \"C\" fn frbgen_aura_notebook_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerstr\([\s\S]*?\n\s*}\n",
        "\n",
        text,
    )
    text = re.sub(
        r"\n\s*pub fn rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerstr\([\s\S]*?\n\s*}\n\s*\n\s*pub fn rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerstr\([\s\S]*?\n\s*}\n",
        "\n",
        text,
    )

    FRB.write_text(text)
    print(f"patched {FRB}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
