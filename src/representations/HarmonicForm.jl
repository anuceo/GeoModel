"""
    HarmonicForm

Layer 2: Spectral geometry representation using harmonic basis functions.

Represents geometric shapes via eigendecomposition of the Laplace-Beltrami operator,
providing a compact, rotation-invariant frequency-domain encoding.
"""
module HarmonicForm

using LinearAlgebra
using SparseArrays
using Arpack

export HarmonicBasis, compute_laplacian, project_to_harmonics

"""
    HarmonicBasis

Spectral basis computed from Laplacian eigenfunctions.
"""
struct HarmonicBasis
    eigenvalues::Vector{Float64}
    eigenvectors::Matrix{Float64}
    n_basis::Int
end

"""
    compute_laplacian(adjacency::SparseMatrixCSC, area_weights::Vector{Float64})

Compute the discrete Laplace-Beltrami operator for a mesh.

# Arguments
- `adjacency::SparseMatrixCSC`: Mesh adjacency (cotangent weights)
- `area_weights::Vector{Float64}`: Vertex area weights

# Returns
- `SparseMatrixCSC`: Symmetric Laplacian matrix
"""
function compute_laplacian(adjacency::SparseMatrixCSC, area_weights::Vector{Float64})
    n = length(area_weights)
    @assert size(adjacency) == (n, n) "Adjacency matrix size mismatch"

    # Normalize by area
    A_inv = spdiagm(1.0 ./ area_weights)
    L = A_inv * adjacency

    # Make symmetric
    return (L + L') / 2
end

"""
    compute_harmonic_basis(laplacian::SparseMatrixCSC, n_basis::Int)

Compute first n_basis eigenfunctions of the Laplacian.

# Arguments
- `laplacian::SparseMatrixCSC`: Laplace-Beltrami operator
- `n_basis::Int`: Number of basis functions to compute

# Returns
- `HarmonicBasis`: Spectral basis
"""
function compute_harmonic_basis(laplacian::SparseMatrixCSC, n_basis::Int)
    # Compute smallest eigenvalues/vectors (ARPACK)
    eigenvalues, eigenvectors = eigs(laplacian, nev=n_basis, which=:SM)

    # Sort by eigenvalue
    idx = sortperm(real(eigenvalues))
    eigenvalues = real(eigenvalues[idx])
    eigenvectors = real(eigenvectors[:, idx])

    return HarmonicBasis(eigenvalues, eigenvectors, n_basis)
end

"""
    project_to_harmonics(basis::HarmonicBasis, signal::Vector{Float64})

Project a scalar field onto the harmonic basis (spectral decomposition).

# Returns
- `Vector{Float64}`: Spectral coefficients
"""
function project_to_harmonics(basis::HarmonicBasis, signal::Vector{Float64})
    @assert length(signal) == size(basis.eigenvectors, 1) "Signal length mismatch"
    return basis.eigenvectors' * signal
end

end # module HarmonicForm
