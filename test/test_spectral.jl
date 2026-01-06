using Test
using GeometryNervousSystem
using LinearAlgebra
using SparseArrays

@testset "Spectral Geometry" begin
    # Create a simple mesh Laplacian
    n = 10  # Number of vertices

    @testset "Laplacian Construction" begin
        # Simple 1D chain graph
        adjacency = spzeros(n, n)
        for i in 1:(n-1)
            adjacency[i, i+1] = -1.0
            adjacency[i+1, i] = -1.0
            adjacency[i, i] = 2.0
        end
        adjacency[n, n] = 1.0

        area_weights = ones(n)

        L = HarmonicForm.compute_laplacian(adjacency, area_weights)

        @test size(L) == (n, n)
        @test issymmetric(L)
    end

    @testset "Harmonic Basis Computation" begin
        # Simple 1D Laplacian
        adjacency = spzeros(n, n)
        for i in 1:(n-1)
            adjacency[i, i+1] = -1.0
            adjacency[i+1, i] = -1.0
            adjacency[i, i] = 2.0
        end
        adjacency[n, n] = 1.0

        area_weights = ones(n)
        L = HarmonicForm.compute_laplacian(adjacency, area_weights)

        # Compute first 5 eigenfunctions
        basis = HarmonicForm.compute_harmonic_basis(L, 5)

        @test length(basis.eigenvalues) == 5
        @test size(basis.eigenvectors) == (n, 5)
        @test basis.n_basis == 5

        # Eigenvalues should be sorted
        @test issorted(basis.eigenvalues)

        # First eigenvalue should be close to 0 (constant function)
        @test basis.eigenvalues[1] < 1e-10
    end

    @testset "Signal Projection" begin
        # Create simple Laplacian
        adjacency = spzeros(n, n)
        for i in 1:(n-1)
            adjacency[i, i+1] = -1.0
            adjacency[i+1, i] = -1.0
            adjacency[i, i] = 2.0
        end
        adjacency[n, n] = 1.0

        area_weights = ones(n)
        L = HarmonicForm.compute_laplacian(adjacency, area_weights)
        basis = HarmonicForm.compute_harmonic_basis(L, 5)

        # Project a signal
        signal = sin.(range(0, 2π, length=n))
        coeffs = HarmonicForm.project_to_harmonics(basis, signal)

        @test length(coeffs) == 5
        # Just check it doesn't crash
    end
end
