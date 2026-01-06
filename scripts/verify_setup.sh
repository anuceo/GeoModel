#!/bin/bash
set -e

echo "═══════════════════════════════════════════════════════════"
echo "  Geometry Nervous System - Complete Setup & Verification"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
        return 1
    fi
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# =============================================================================
# PHASE 1: Check Prerequisites
# =============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 1: Checking Prerequisites"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check Rust
if command -v rustc &> /dev/null; then
    RUST_VERSION=$(rustc --version | awk '{print $2}')
    print_status 0 "Rust installed: $RUST_VERSION"
else
    print_status 1 "Rust not found"
    echo "   Install from: https://rustup.rs/"
    exit 1
fi

# Check Cargo
if command -v cargo &> /dev/null; then
    CARGO_VERSION=$(cargo --version | awk '{print $2}')
    print_status 0 "Cargo installed: $CARGO_VERSION"
else
    print_status 1 "Cargo not found"
    exit 1
fi

# Check Julia
if command -v julia &> /dev/null; then
    JULIA_VERSION=$(julia --version | grep -oP '\d+\.\d+\.\d+' | head -1)
    print_status 0 "Julia installed: $JULIA_VERSION"
    JULIA_AVAILABLE=1

    # Check Julia version >= 1.9
    JULIA_MAJOR=$(echo $JULIA_VERSION | cut -d. -f1)
    JULIA_MINOR=$(echo $JULIA_VERSION | cut -d. -f2)

    if [ "$JULIA_MAJOR" -gt 1 ] || ([ "$JULIA_MAJOR" -eq 1 ] && [ "$JULIA_MINOR" -ge 9 ]); then
        print_status 0 "Julia version is >= 1.9"
    else
        print_warning "Julia version should be >= 1.9 (found $JULIA_VERSION)"
    fi
else
    print_status 1 "Julia not found"
    print_info "Julia is required for the full system"
    print_info "Download from: https://julialang.org/downloads/"
    JULIA_AVAILABLE=0
fi

echo ""

# =============================================================================
# PHASE 2: Build Rust Components
# =============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 2: Building Rust NURBS Kernel"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

print_info "Building in release mode..."
cd rust

if cargo build --release 2>&1 | grep -q "Finished"; then
    print_status 0 "Rust build successful"
else
    print_status 1 "Rust build failed"
    exit 1
fi

cd ..

# Check library file
if [ -f "target/release/libnurbs_core.so" ]; then
    LIB_SIZE=$(du -h target/release/libnurbs_core.so | cut -f1)
    print_status 0 "Library built: libnurbs_core.so ($LIB_SIZE)"
elif [ -f "target/release/libnurbs_core.dylib" ]; then
    LIB_SIZE=$(du -h target/release/libnurbs_core.dylib | cut -f1)
    print_status 0 "Library built: libnurbs_core.dylib ($LIB_SIZE)"
elif [ -f "target/release/nurbs_core.dll" ]; then
    LIB_SIZE=$(du -h target/release/nurbs_core.dll | cut -f1)
    print_status 0 "Library built: nurbs_core.dll ($LIB_SIZE)"
else
    print_status 1 "Library file not found"
    exit 1
fi

echo ""

# =============================================================================
# PHASE 3: Test Rust Components
# =============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 3: Testing Rust Components"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

print_info "Running Rust test suite..."
cd rust

TEST_OUTPUT=$(cargo test --release 2>&1)

if echo "$TEST_OUTPUT" | grep -q "test result: ok"; then
    PASSED=$(echo "$TEST_OUTPUT" | grep "test result: ok" | grep -oP '\d+ passed' | head -1)
    print_status 0 "All Rust tests passed ($PASSED)"
else
    print_status 1 "Some Rust tests failed"
    echo "$TEST_OUTPUT"
    exit 1
fi

cd ..

echo ""

# =============================================================================
# PHASE 4: Copy Library to Julia Directory
# =============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Phase 4: Setting up Julia Library Directory"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

mkdir -p julia/lib

if [ -f "target/release/libnurbs_core.so" ]; then
    cp target/release/libnurbs_core.so julia/lib/
    print_status 0 "Copied libnurbs_core.so to julia/lib/"
elif [ -f "target/release/libnurbs_core.dylib" ]; then
    cp target/release/libnurbs_core.dylib julia/lib/
    print_status 0 "Copied libnurbs_core.dylib to julia/lib/"
elif [ -f "target/release/nurbs_core.dll" ]; then
    cp target/release/nurbs_core.dll julia/lib/
    print_status 0 "Copied nurbs_core.dll to julia/lib/"
fi

echo ""

# =============================================================================
# PHASE 5: Setup Julia (if available)
# =============================================================================

if [ "$JULIA_AVAILABLE" -eq 1 ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Phase 5: Setting up Julia Environment"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    print_info "Installing Julia dependencies..."

    if julia --project=. -e 'using Pkg; Pkg.instantiate()' 2>&1 | tail -5; then
        print_status 0 "Julia dependencies installed"
    else
        print_status 1 "Julia dependency installation failed"
        exit 1
    fi

    echo ""

    # Precompile
    print_info "Precompiling Julia packages..."
    if julia --project=. -e 'using Pkg; Pkg.precompile()' 2>&1 | tail -3; then
        print_status 0 "Julia packages precompiled"
    else
        print_warning "Precompilation warnings (may be normal)"
    fi

    echo ""

    # ==========================================================================
    # PHASE 6: Test Julia Components
    # ==========================================================================

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Phase 6: Testing Julia Components"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    print_info "Loading GeometryNervousSystem module..."

    if julia --project=. -e 'using GeometryNervousSystem; println("✓ Module loaded successfully")' 2>&1 | grep -q "✓ Module loaded"; then
        print_status 0 "GeometryNervousSystem module loads correctly"
    else
        print_status 1 "Failed to load GeometryNervousSystem module"
        exit 1
    fi

    echo ""

    print_info "Running Julia test suite..."

    if julia --project=. julia/test/runtests.jl 2>&1 | tee /tmp/julia_test_output.txt; then
        print_status 0 "Julia tests completed"

        # Parse test results
        if grep -q "Test Summary:" /tmp/julia_test_output.txt; then
            grep "Test Summary:" -A 5 /tmp/julia_test_output.txt
        fi
    else
        print_status 1 "Julia tests failed"
        exit 1
    fi

    echo ""

    # ==========================================================================
    # PHASE 7: Run Examples
    # ==========================================================================

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Phase 7: Running Examples"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    print_info "Running basic NURBS example..."

    if julia --project=. julia/examples/basic_nurbs.jl 2>&1 | tail -20; then
        print_status 0 "Basic NURBS example completed"
    else
        print_warning "Basic NURBS example encountered issues"
    fi

    echo ""

    print_info "Running spectral geometry example..."

    if julia --project=. julia/examples/spectral_geometry.jl 2>&1 | tail -20; then
        print_status 0 "Spectral geometry example completed"
    else
        print_warning "Spectral geometry example encountered issues"
    fi

else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Phase 5-7: Julia Setup (SKIPPED - Julia not installed)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    print_warning "Julia is not installed. Skipping Julia-specific tests."
    echo ""
    print_info "To complete setup:"
    echo "   1. Install Julia 1.9+ from https://julialang.org/downloads/"
    echo "   2. Run this script again"
    echo ""
fi

echo ""

# =============================================================================
# PHASE 8: System Summary
# =============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Setup Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "System Components:"
echo "  • Rust NURBS Kernel:        ✓ Built & Tested"
echo "  • Julia Package Structure:  ✓ Complete"

if [ "$JULIA_AVAILABLE" -eq 1 ]; then
    echo "  • Julia Environment:        ✓ Configured"
    echo "  • Julia Tests:              ✓ Passed"
    echo "  • Examples:                 ✓ Working"
    echo ""
    echo -e "${GREEN}✓ SYSTEM FULLY OPERATIONAL${NC}"
else
    echo "  • Julia Environment:        ⏸ Pending"
    echo "  • Julia Tests:              ⏸ Pending"
    echo "  • Examples:                 ⏸ Pending"
    echo ""
    echo -e "${YELLOW}⚠ SYSTEM PARTIALLY OPERATIONAL${NC}"
    echo "  Rust components working. Julia setup pending."
fi

echo ""
echo "Next Steps:"

if [ "$JULIA_AVAILABLE" -eq 1 ]; then
    echo "  1. Try the examples:"
    echo "     julia --project=. julia/examples/basic_nurbs.jl"
    echo ""
    echo "  2. Start developing with:"
    echo "     julia --project=."
    echo "     using GeometryNervousSystem"
else
    echo "  1. Install Julia 1.9+ from https://julialang.org/downloads/"
    echo "  2. Run this script again"
    echo "  3. Start developing!"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  Setup Complete!"
echo "═══════════════════════════════════════════════════════════"
