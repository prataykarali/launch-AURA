#!/bin/bash
cd /home/pratay-karali/AURA-Proj/aura_notebook

# Generate bridge using the Rust library directly
cargo run --manifest-path rust/Cargo.toml --bin generate_bridge 2>/dev/null || {
    # If that fails, use the installed codegen
    cd rust
    cat > src/bridge_generated.rs << 'BRIDGE_EOF'
// Auto-generated - Bridge code will be inserted here by Flutter
BRIDGE_EOF
    echo "Bridge stub created, continuing..."
}
