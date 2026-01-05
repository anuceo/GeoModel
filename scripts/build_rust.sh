#!/bin/bash
set -e

echo "=== Building Rust NURBS Kernel ==="
echo ""

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo "Error: Rust/Cargo not found!"
    echo "Please install Rust from https://rustup.rs/"
    exit 1
fi

echo "Rust version: $(rustc --version)"
echo "Cargo version: $(cargo --version)"
echo ""

# Build in release mode
echo "Building Rust libraries in release mode..."
cd rust
cargo build --release --workspace

if [ $? -eq 0 ]; then
    echo "✓ Rust build successful"
else
    echo "✗ Rust build failed"
    exit 1
fi

# Copy libraries to Julia lib directory
echo ""
echo "Copying libraries to julia/lib/..."
cd ..
mkdir -p julia/lib

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    cp rust/target/release/libnurbs_core.so julia/lib/ 2>/dev/null || true
    echo "✓ Copied libnurbs_core.so"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    cp rust/target/release/libnurbs_core.dylib julia/lib/ 2>/dev/null || true
    echo "✓ Copied libnurbs_core.dylib"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    cp rust/target/release/nurbs_core.dll julia/lib/ 2>/dev/null || true
    echo "✓ Copied nurbs_core.dll"
fi

echo ""
echo "=== Build Complete ==="
echo "Library location: julia/lib/"
echo ""
echo "Next steps:"
echo "  1. Test Rust library: cd rust && cargo test"
echo "  2. Run Julia tests: julia --project=. julia/test/runtests.jl"
