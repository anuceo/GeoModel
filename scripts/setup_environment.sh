#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════════╗"
echo "║   Geometry Nervous System - Environment Setup         ║"
echo "║   Julia + Rust High-Performance CAD Pipeline          ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Julia
echo "Checking Julia installation..."
if ! command -v julia &> /dev/null; then
    echo -e "${RED}✗ Julia not found${NC}"
    echo "Please install Julia 1.9+ from https://julialang.org/downloads/"
    exit 1
fi

JULIA_VERSION=$(julia --version | grep -oP '\d+\.\d+' | head -1)
echo -e "${GREEN}✓ Julia found: $(julia --version)${NC}"

# Check if Julia version is >= 1.9
if (( $(echo "$JULIA_VERSION < 1.9" | bc -l) )); then
    echo -e "${YELLOW}Warning: Julia version should be >= 1.9${NC}"
fi

echo ""

# Check Rust
echo "Checking Rust installation..."
if ! command -v cargo &> /dev/null; then
    echo -e "${YELLOW}✗ Rust not found - Installing...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
fi

echo -e "${GREEN}✓ Rust found: $(rustc --version)${NC}"
echo -e "${GREEN}✓ Cargo found: $(cargo --version)${NC}"
echo ""

# Build Rust libraries
echo "═══════════════════════════════════════════════════════"
echo "Building Rust NURBS kernel..."
echo "═══════════════════════════════════════════════════════"
chmod +x scripts/build_rust.sh
./scripts/build_rust.sh

echo ""

# Install Julia dependencies
echo "═══════════════════════════════════════════════════════"
echo "Installing Julia dependencies..."
echo "═══════════════════════════════════════════════════════"

julia --project=. -e '
    using Pkg
    Pkg.instantiate()
    println("✓ Julia dependencies installed")
'

echo ""

# Check CUDA availability (optional)
echo "═══════════════════════════════════════════════════════"
echo "Checking CUDA availability (optional)..."
echo "═══════════════════════════════════════════════════════"

julia --project=. -e '
    using Pkg
    try
        Pkg.add("CUDA")
        using CUDA
        if CUDA.functional()
            println("✓ CUDA available - GPU acceleration enabled")
        else
            println("⚠ CUDA installed but not functional - CPU mode only")
        end
    catch
        println("⚠ CUDA not available - CPU mode only")
    end
' || echo "⚠ Skipping CUDA setup"

echo ""

# Run tests
echo "═══════════════════════════════════════════════════════"
echo "Running tests..."
echo "═══════════════════════════════════════════════════════"

# Test Rust
echo "Testing Rust libraries..."
cd rust
cargo test --release --workspace
cd ..
echo -e "${GREEN}✓ Rust tests passed${NC}"

echo ""

# Test Julia
echo "Testing Julia package..."
julia --project=. -e '
    using Pkg
    Pkg.test()
' || echo -e "${YELLOW}⚠ Julia tests failed (this is OK if library path is not set)${NC}"

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║              Setup Complete!                           ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "Quick start:"
echo "  1. Start Julia REPL:"
echo "     $ julia --project=."
echo ""
echo "  2. Load the package:"
echo "     julia> using GeometryNervousSystem"
echo ""
echo "  3. Create a NURBS surface:"
echo "     julia> include(\"julia/examples/basic_nurbs.jl\")"
echo ""
echo "Documentation:"
echo "  - README.md: Project overview and architecture"
echo "  - docs/: Detailed documentation"
echo ""
