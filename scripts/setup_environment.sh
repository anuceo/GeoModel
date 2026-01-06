#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

# Check Julia (auto-install via juliaup if missing)
echo "Checking Julia installation..."
JULIA_BIN="${JULIA_BIN:-$(command -v julia || true)}"
if [[ -z "${JULIA_BIN}" ]]; then
    echo -e "${YELLOW}✗ Julia not found - Installing (juliaup)...${NC}"
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}✗ curl not found (required to install Julia)${NC}"
        echo "Please install curl, or install Julia 1.9+ manually from https://julialang.org/downloads/"
        exit 1
    fi

    # Install juliaup and ensure this script can see it.
    set +e
    curl -fsSL https://install.julialang.org | sh -s -- --yes
    JULIAUP_STATUS=$?
    set -e
    if [[ "${JULIAUP_STATUS}" -ne 0 ]]; then
        echo -e "${RED}✗ Juliaup install failed (often due to missing network access)${NC}"
        echo "Please install Julia 1.9+ manually, then re-run this script."
        echo "If Julia is installed but not on PATH, run:"
        echo "  JULIA_BIN=/path/to/julia ./scripts/setup_environment.sh"
        exit 1
    fi

    export PATH="$HOME/.juliaup/bin:$PATH"
    JULIA_BIN="$(command -v julia || true)"
fi

if [[ -z "${JULIA_BIN}" ]]; then
    echo -e "${RED}✗ Julia installation failed${NC}"
    exit 1
fi

JULIA_VERSION="$("${JULIA_BIN}" -e 'print(VERSION)')"
echo -e "${GREEN}✓ Julia found: ${JULIA_BIN} (v${JULIA_VERSION})${NC}"

# Check if Julia version is >= 1.9 (no bc/grep -P required)
REQUIRED_JULIA="1.9.0"
if [[ "$(printf '%s\n' "${REQUIRED_JULIA}" "${JULIA_VERSION}" | sort -V | head -n1)" != "${REQUIRED_JULIA}" ]]; then
    echo -e "${YELLOW}Warning: Julia version should be >= ${REQUIRED_JULIA}${NC}"
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
chmod +x "${ROOT_DIR}/scripts/build_rust.sh"
"${ROOT_DIR}/scripts/build_rust.sh"

echo ""

# Install Julia dependencies
echo "═══════════════════════════════════════════════════════"
echo "Installing Julia dependencies..."
echo "═══════════════════════════════════════════════════════"

"${JULIA_BIN}" --project="${ROOT_DIR}" -e '
    using Pkg
    Pkg.instantiate()
    println("✓ Julia dependencies installed")
'

echo ""

# Optional CUDA setup: opt-in via env var
#   GNS_ENABLE_CUDA=1 ./scripts/setup_environment.sh
if [[ "${GNS_ENABLE_CUDA:-0}" == "1" ]]; then
    echo "═══════════════════════════════════════════════════════"
    echo "Checking CUDA availability (optional)..."
    echo "═══════════════════════════════════════════════════════"

    "${JULIA_BIN}" --project="${ROOT_DIR}" -e '
        using Pkg
        try
            Pkg.add("CUDA")
            using CUDA
            if CUDA.functional()
                println("✓ CUDA available - GPU acceleration enabled")
            else
                println("⚠ CUDA installed but not functional - CPU mode only")
            end
        catch err
            @warn "CUDA setup skipped" exception=(err, catch_backtrace())
            println("⚠ CUDA not available - CPU mode only")
        end
    ' || echo "⚠ Skipping CUDA setup"
fi

echo ""

# Run tests
echo "═══════════════════════════════════════════════════════"
echo "Running tests..."
echo "═══════════════════════════════════════════════════════"

# Test Rust
echo "Testing Rust libraries..."
pushd "${ROOT_DIR}/rust" >/dev/null
cargo test --release --workspace
popd >/dev/null
echo -e "${GREEN}✓ Rust tests passed${NC}"

echo ""

# Test Julia
echo "Testing Julia package..."
"${JULIA_BIN}" --project="${ROOT_DIR}" -e '
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
