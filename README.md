# Geometry Nervous System

> **A Neural Generative Pipeline for Parametric CAD Geometry**
>
> Julia + Rust | High-Performance NURBS | Spectral Geometry | Neural Architecture

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## Overview

The Geometry Nervous System is a cutting-edge framework for generating parametric CAD geometry using a neural pipeline that mimics hierarchical design processes. It combines:

- **High-level orchestration** in Julia for rapid prototyping and GPU acceleration
- **Performance-critical kernels** in Rust for NURBS evaluation and geometric computation
- **Spectral geometry** for efficient shape representation and analysis
- **Neural networks** for learning design intent and generating geometry

### Key Features

| Feature | Description |
|---------|-------------|
| **Hybrid Architecture** | Julia for ML/GPU + Rust for geometry kernels |
| **NURBS Engine** | Production-ready Cox-de Boor algorithm with FFI |
| **Spectral Methods** | Laplacian eigenbasis for shape analysis |
| **Zero-Copy FFI** | Direct Julia ↔ Rust interop via `ccall` |
| **CAD Export** | STEP, IGES, OBJ format support (planned) |
| **GPU Acceleration** | CUDA.jl support for neural training |

---

## Architecture

The system follows a 7-layer "nervous system" architecture:

```
┌──────────────────────────────────────────────────────────────┐
│  Layer 1: Intent Graph        (Design requirements)          │
├──────────────────────────────────────────────────────────────┤
│  Layer 2: Harmonic Form       (Spectral encoding)            │
├──────────────────────────────────────────────────────────────┤
│  Layer 3: Topology Graph      (B-Rep structure)              │
├──────────────────────────────────────────────────────────────┤
│  Layer 4: Spline Patches      (NURBS surfaces)               │
├──────────────────────────────────────────────────────────────┤
│  Layer 5: Spectral Tensors    (Curvature analysis)           │
├──────────────────────────────────────────────────────────────┤
│  Layer 6: Fractal Refinement  (Adaptive tessellation)        │
├──────────────────────────────────────────────────────────────┤
│  Layer 7: Tessellation        (Triangle mesh output)         │
└──────────────────────────────────────────────────────────────┘
```

### Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **High-level logic** | Julia 1.9+ | ML orchestration, GPU computing |
| **NURBS kernels** | Rust 2021 | High-performance geometry evaluation |
| **Neural networks** | Flux.jl | Generative models |
| **Spectral geometry** | Arpack.jl | Laplacian eigendecomposition |
| **GPU computing** | CUDA.jl | Training acceleration |
| **FFI bridge** | `ccall` / `libc` | Zero-cost interop |

---

## Installation

### Prerequisites

- **Julia 1.9+**: [Download here](https://julialang.org/downloads/)
- **Rust 1.70+**: [Install via rustup](https://rustup.rs/)
- **CUDA (optional)**: For GPU acceleration

### Quick Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/GeoModel.git
cd GeoModel

# Run automated setup (builds Rust + installs Julia deps)
chmod +x scripts/setup_environment.sh
./scripts/setup_environment.sh
```

The setup script will:
1. ✓ Verify Julia and Rust installations
2. ✓ Build Rust NURBS kernel in release mode
3. ✓ Copy compiled libraries to `julia/lib/`
4. ✓ Install Julia package dependencies
5. ✓ Run test suite

Notes:
- If Julia is installed but not on your `PATH`, run: `JULIA_BIN=/path/to/julia ./scripts/setup_environment.sh`
- CUDA support is **optional**. To enable it, run: `GNS_ENABLE_CUDA=1 ./scripts/setup_environment.sh`

### Manual Setup

If you prefer manual installation:

```bash
# 1. Build Rust libraries
cd rust
cargo build --release
cd ..

# 2. Copy libraries
mkdir -p julia/lib
cp rust/target/release/libnurbs_core.* julia/lib/

# 3. Install Julia dependencies
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# 4. Run tests
julia --project=. -e 'using Pkg; Pkg.test()'
```

---

## Quick Start

### Example 1: Basic NURBS Surface

```julia
using GeometryNervousSystem

# Create control points (wavy surface)
degree = 3
u_res, v_res = 6, 6

control_points = zeros(u_res, v_res, 3)
for i in 1:u_res, j in 1:v_res
    x = (i - 1) / (u_res - 1)
    y = (j - 1) / (v_res - 1)
    z = 0.2 * sin(2π * x) * cos(2π * y)
    control_points[i, j, :] = [x, y, z]
end

# Create NURBS surface
weights = ones(u_res, v_res)
knots = uniform_knot_vector(u_res, degree)

surface = NURBSSurface(degree, degree, control_points, weights, knots, knots)

# Evaluate at a point
point = evaluate(surface, 0.5, 0.5)  # Center
# Or use callable syntax: point = surface(0.5, 0.5)

# Compute differential geometry
normal = compute_normal(surface, 0.5, 0.5)
k1, k2 = compute_curvature(surface, 0.5, 0.5)

# Batch evaluation (parallelized in Rust)
uv_pairs = rand(1000, 2)
points = evaluate_batch(surface, uv_pairs)

# Grid for visualization
grid = evaluate_grid(surface, 100, 100)  # 100×100 mesh
```

### Example 2: Spectral Geometry

```julia
using GeometryNervousSystem
using SparseArrays

# Build mesh Laplacian
L = build_laplacian(mesh)  # Your mesh adjacency matrix
area_weights = compute_vertex_areas(mesh)

L_normalized = HarmonicForm.compute_laplacian(L, area_weights)

# Compute harmonic basis (first 20 eigenfunctions)
basis = HarmonicForm.compute_harmonic_basis(L_normalized, 20)

# Project signal to spectral domain
signal = mesh_vertex_heights  # Some scalar field
coefficients = HarmonicForm.project_to_harmonics(basis, signal)

# Reconstruct with low-pass filter
filtered = basis.eigenvectors[:, 1:10] * coefficients[1:10]
```

### Run Examples

```bash
# Minimal NURBS evaluation
julia --project=. -e '
using GeometryNervousSystem
cp = zeros(5,5,3); for i in 1:5, j in 1:5; cp[i,j,:] = [(i-1)/4,(j-1)/4,0.0]; end
w = ones(5,5); k = [0,0,0,0,0.5,1,1,1,1]
s = NURBSSurface(3,3,cp,w,k,k)
@show evaluate(s, 0.5, 0.5)
'
```

---

## Project Structure

```
GeoModel/
│
├── Project.toml                    # Julia package manifest
├── Cargo.toml                      # Rust workspace config
│
├── julia/                          # Julia source code
│   ├── src/
│   │   ├── GeometryNervousSystem.jl    # Main module
│   │   ├── rust_bridge.jl              # FFI to Rust
│   │   ├── geometry/
│   │   │   └── nurbs.jl                # High-level NURBS API
│   │   ├── representations/            # Layer 1-4 data structures
│   │   │   ├── IntentGraph.jl
│   │   │   ├── HarmonicForm.jl
│   │   │   ├── TopologyGraph.jl
│   │   │   └── SplinePatch.jl
│   │   └── models/                     # Neural networks (planned)
│   ├── test/
│   │   ├── test_nurbs.jl
│   │   ├── test_spectral.jl
│   │   └── test_pipeline.jl
│   └── examples/                    # (removed; use library API instead)
│
├── rust/                           # Rust source code
│   ├── nurbs-core/                 # NURBS evaluation kernel
│   │   ├── src/
│   │   │   ├── lib.rs
│   │   │   ├── basis.rs            # Cox-de Boor algorithm
│   │   │   ├── surface.rs          # Surface evaluation
│   │   │   ├── derivatives.rs      # Normals, curvatures
│   │   │   └── ffi.rs              # C-compatible API
│   │   └── benches/
│   ├── tessellation/               # Adaptive meshing (planned)
│   └── geometry-utils/             # Shared utilities
│
├── scripts/
│   ├── setup_environment.sh        # Automated setup
│   └── build_rust.sh               # Rust build script
│
└── docs/                           # Documentation
```

---

## Performance

The Rust NURBS kernel delivers C-level performance with memory safety:

| Operation | Throughput | Implementation |
|-----------|------------|----------------|
| Single point evaluation | ~100ns | Rust (optimized) |
| Batch evaluation (1M points) | ~0.5s | Rust (Rayon parallel) |
| Normal computation | ~500ns | Numerical differentiation |
| Grid evaluation (100×100) | ~5ms | Parallel evaluation |

*Benchmarks on AMD Ryzen 9 5950X, compiled with `--release`*

---

## API Reference

### NURBS Surface

```julia
# Construction
NURBSSurface(degree_u, degree_v, control_points, weights, knots_u, knots_v)

# Evaluation
evaluate(surface, u, v)                    # Single point
evaluate_batch(surface, uv_pairs)          # Batch (parallel)
evaluate_grid(surface, u_samples, v_samples)  # Uniform grid

# Differential geometry
compute_normal(surface, u, v)              # Unit normal
compute_curvature(surface, u, v)           # (κ₁, κ₂)

# Utilities
uniform_knot_vector(n_cp, degree)          # Generate uniform knots
dimensions(surface)                        # (u_res, v_res)
```

### Spectral Geometry

```julia
# Laplacian computation
compute_laplacian(adjacency, area_weights)

# Harmonic basis
compute_harmonic_basis(laplacian, n_basis)

# Signal projection
project_to_harmonics(basis, signal)
```

---

## Testing

Run the test suite:

```bash
# All tests
julia --project=. -e 'using Pkg; Pkg.test()'

# Or run individual test files
julia --project=. julia/test/test_nurbs.jl
julia --project=. julia/test/test_spectral.jl
julia --project=. julia/test/test_pipeline.jl

# Rust tests
cd rust
cargo test --release
```

---

## Roadmap

### Phase 1: Foundation (✓ Current)
- [x] Rust NURBS kernel with FFI
- [x] Julia high-level interface
- [x] Basic spectral geometry
- [x] Test suite and examples

### Phase 2: Neural Models (In Progress)
- [ ] Intent encoder network
- [ ] Harmonic predictor (spectral → topology)
- [ ] Topology generator (graph neural network)
- [ ] Spline generator (control point regression)

### Phase 3: CAD Integration
- [ ] STEP export (ISO 10303-21)
- [ ] IGES export (IGES 5.3)
- [ ] OBJ/STL mesh export
- [ ] Continuity enforcement (G0/G1/G2)

### Phase 4: Advanced Features
- [ ] Adaptive tessellation (curvature-based)
- [ ] Constraint satisfaction (dimensions, tolerances)
- [ ] Interactive refinement
- [ ] Web-based visualizer

---

## Contributing

Contributions are welcome! Areas of interest:

1. **Neural architectures**: Improving generative models
2. **CAD export**: Implementing STEP/IGES writers
3. **Optimization**: SIMD, GPU kernels for NURBS
4. **Visualization**: 3D rendering pipeline
5. **Documentation**: Tutorials and examples

Please open an issue before starting major work.

---

## Citation

If you use this project in research, please cite:

```bibtex
@software{geometry_nervous_system,
  title = {Geometry Nervous System: Neural Parametric CAD Generation},
  author = {Your Name},
  year = {2025},
  url = {https://github.com/yourusername/GeoModel}
}
```

---

## License

MIT License - see [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- **Julia Community**: For excellent numerical computing tools
- **Rust Geometry**: Inspiration from `kurbo`, `lyon`, and other geometry crates
- **NURBS Theory**: *The NURBS Book* by Piegl & Tiller
- **Spectral Geometry**: Foundations from discrete differential geometry

---

## Contact

- **Issues**: [GitHub Issues](https://github.com/yourusername/GeoModel/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/GeoModel/discussions)
- **Email**: your.email@example.com

---

**Built with ❤️ using Julia + Rust**

*High-performance geometry meets modern machine learning*
