#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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
pushd "${ROOT_DIR}/rust" >/dev/null
cargo build --release --workspace

echo "✓ Rust build successful"

# Copy libraries to Julia lib directory
echo ""
echo "Copying libraries to julia/lib/..."
popd >/dev/null
mkdir -p "${ROOT_DIR}/julia/lib"

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if [[ -f "${ROOT_DIR}/target/release/libnurbs_core.so" ]]; then
        cp "${ROOT_DIR}/target/release/libnurbs_core.so" "${ROOT_DIR}/julia/lib/"
        echo "✓ Copied libnurbs_core.so"
    else
        echo "✗ Expected library not found: ${ROOT_DIR}/target/release/libnurbs_core.so"
        exit 1
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ -f "${ROOT_DIR}/target/release/libnurbs_core.dylib" ]]; then
        cp "${ROOT_DIR}/target/release/libnurbs_core.dylib" "${ROOT_DIR}/julia/lib/"
        echo "✓ Copied libnurbs_core.dylib"
    else
        echo "✗ Expected library not found: ${ROOT_DIR}/target/release/libnurbs_core.dylib"
        exit 1
    fi
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    if [[ -f "${ROOT_DIR}/target/release/nurbs_core.dll" ]]; then
        cp "${ROOT_DIR}/target/release/nurbs_core.dll" "${ROOT_DIR}/julia/lib/"
        echo "✓ Copied nurbs_core.dll"
    else
        echo "✗ Expected library not found: ${ROOT_DIR}/target/release/nurbs_core.dll"
        exit 1
    fi
fi

echo ""
echo "=== Build Complete ==="
echo "Library location: julia/lib/"
echo ""
echo "Next steps:"
echo "  1. Test Rust library: cd rust && cargo test"
echo "  2. Run Julia tests: julia --project=. julia/test/runtests.jl"
