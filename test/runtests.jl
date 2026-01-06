using Test

# Delegate to the existing test suite under `julia/test/`.
include(joinpath(@__DIR__, "..", "julia", "test", "runtests.jl"))

