using Test
using GeometryNervousSystem

@testset "GeometryNervousSystem.jl" begin
    @testset "NURBS Basics" begin
        include("test_nurbs.jl")
    end

    @testset "Spectral Geometry" begin
        include("test_spectral.jl")
    end

    @testset "Full Pipeline" begin
        include("test_pipeline.jl")
    end
end
