"""
    GeometryNervousSystem

A neural generative pipeline for parametric CAD geometry, combining:
- High-level intent understanding
- Spectral geometry processing
- NURBS surface generation
- CAD export capabilities

Built with Julia for high-level orchestration and Rust for performance-critical kernels.
"""
module GeometryNervousSystem

# Standard library
using LinearAlgebra
using SparseArrays
using Statistics

# External dependencies
using StaticArrays
using GeometryBasics
using DataStructures

# Re-exports
export NURBSSurface, evaluate, evaluate_batch, evaluate_grid, compute_normal, uniform_knot_vector

# Core modules
include("rust_bridge.jl")
include("geometry/nurbs.jl")

# Representations (Layer 1-7 of the nervous system)
include("representations/IntentGraph.jl")
include("representations/HarmonicForm.jl")
include("representations/TopologyGraph.jl")
include("representations/SplinePatch.jl")

# Neural models
# include("models/IntentEncoder.jl")
# include("models/HarmonicPredictor.jl")
# include("models/TopologyGenerator.jl")
# include("models/SplineGenerator.jl")

# Geometry algorithms
# include("geometry/spectral.jl")
# include("geometry/curvature.jl")
# include("geometry/continuity.jl")

# Training infrastructure
# include("training/losses.jl")
# include("training/trainer.jl")

# Export
# include("export/step.jl")
# include("export/iges.jl")
# include("export/obj.jl")

end # module GeometryNervousSystem
