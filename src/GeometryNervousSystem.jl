"""
    GeometryNervousSystem

Package entrypoint.

The implementation lives in `julia/src/` (kept to preserve the repo layout).
This shim exists so `Pkg` can find `src/GeometryNervousSystem.jl` at the
project root and successfully precompile the package.
"""

include(joinpath(@__DIR__, "..", "julia", "src", "GeometryNervousSystem.jl"))

