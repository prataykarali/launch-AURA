#!/usr/bin/env python3
import os
import sys

def main():
    try:
        import onnx
    except ImportError:
        print("Error: The 'onnx' Python package is required. Please install it first using: pip install onnx")
        sys.exit(1)

    model_dir = "/home/pratay-karali/launch-AURA/AURA-Proj/aura_notebook/assets/piper"
    model_path = os.path.join(model_dir, "en_US-lessac-medium.onnx")

    if not os.path.exists(model_path):
        print(f"Error: Model file not found at {model_path}")
        sys.exit(1)

    print(f"Loading ONNX model from {model_path}...")
    model = onnx.load(model_path)

    # Check if sample_rate is already present
    exists = False
    for prop in model.metadata_props:
        if prop.key == "sample_rate":
            print(f"Metadata property 'sample_rate' already exists with value '{prop.value}'")
            exists = True
            break

    if not exists:
        print("Injecting 'sample_rate' = '22050' into ONNX model metadata...")
        meta = model.metadata_props.add()
        meta.key = "sample_rate"
        meta.value = "22050"
        
        print("Saving modified model...")
        onnx.save(model, model_path)
        print("Model metadata successfully updated!")
    else:
        print("No modifications needed.")

if __name__ == "__main__":
    main()
