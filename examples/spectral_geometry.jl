"""
Spectral Geometry Example

Demonstrates:
- Building a mesh Laplacian
- Computing harmonic basis (eigenfunctions)
- Signal processing in spectral domain
- Potential application to shape analysis
"""

using GeometryNervousSystem
using LinearAlgebra
using SparseArrays

println("=== Spectral Geometry Example ===\n")

# 1. Create a simple 2D grid mesh
println("Creating 2D grid mesh...")

n_x = 10
n_y = 10
n_vertices = n_x * n_y

# Build graph Laplacian for grid (finite differences)
function build_grid_laplacian(nx::Int, ny::Int)
    n = nx * ny
    L = spzeros(n, n)

    for i in 1:nx, j in 1:ny
        idx = (j - 1) * nx + i

        # 4-neighbors (up, down, left, right)
        neighbors = Int[]

        if i > 1
            push!(neighbors, (j - 1) * nx + (i - 1))  # Left
        end
        if i < nx
            push!(neighbors, (j - 1) * nx + (i + 1))  # Right
        end
        if j > 1
            push!(neighbors, (j - 2) * nx + i)  # Down
        end
        if j < ny
            push!(neighbors, j * nx + i)  # Up
        end

        # Diagonal entry
        L[idx, idx] = length(neighbors)

        # Off-diagonal entries
        for nbr in neighbors
            L[idx, nbr] = -1
        end
    end

    return L
end

L = build_grid_laplacian(n_x, n_y)

println("  Grid size: $n_x × $n_y")
println("  Vertices: $n_vertices")
println("  Laplacian: $(size(L))")
println()

# 2. Compute harmonic basis
println("Computing harmonic basis (eigendecomposition)...")

area_weights = ones(n_vertices)  # Uniform area
L_normalized = HarmonicForm.compute_laplacian(L, area_weights)

n_basis = 20
@time basis = HarmonicForm.compute_harmonic_basis(L_normalized, n_basis)

println("  Computed $n_basis eigenfunctions")
println()

# 3. Display eigenvalues (spectrum)
println("Laplacian spectrum (first $n_basis eigenvalues):")
for (i, λ) in enumerate(basis.eigenvalues)
    println("  λ[$i] = $(round(λ, digits=6))")
end
println()

# 4. Create a test signal (spatial function on mesh)
println("Creating test signal...")

# Signal: Gaussian bump at center
function create_gaussian_signal(nx, ny, σ=2.0)
    signal = zeros(nx * ny)
    cx, cy = nx / 2, ny / 2

    for i in 1:nx, j in 1:ny
        idx = (j - 1) * nx + i
        dist_sq = (i - cx)^2 + (j - cy)^2
        signal[idx] = exp(-dist_sq / (2 * σ^2))
    end

    return signal
end

signal = create_gaussian_signal(n_x, n_y, 2.0)

println("  Signal type: Gaussian bump")
println("  Signal range: [$(round(minimum(signal), digits=4)), $(round(maximum(signal), digits=4))]")
println()

# 5. Project signal to spectral domain
println("Projecting signal to harmonic basis...")

coefficients = HarmonicForm.project_to_harmonics(basis, signal)

println("  Spectral coefficients (first 10):")
for (i, c) in enumerate(coefficients[1:10])
    println("    c[$i] = $(round(c, digits=6))")
end
println()

# 6. Reconstruct signal (truncated)
println("Reconstructing signal from spectral coefficients...")

# Use only first k coefficients (low-pass filter)
k_truncate = 10
signal_reconstructed = basis.eigenvectors[:, 1:k_truncate] * coefficients[1:k_truncate]

# Compute reconstruction err or
error = norm(signal - signal_reconstructed) / norm(signal)

println("  Using $k_truncate / $n_basis coefficients")
println("  Relative error: $(round(error * 100, digits=2))%")
println()

# 7. Spectral filtering example
println("Spectral filtering (low-pass)...")

# Create a noisy signal
noisy_signal = signal .+ 0.1 * randn(length(signal))

# Project to spectral domain
noisy_coeffs = HarmonicForm.project_to_harmonics(basis, noisy_signal)

# Apply low-pass filter (keep only low frequencies)
filtered_coeffs = copy(noisy_coeffs)
filtered_coeffs[11:end] .= 0.0  # Zero out high frequencies

# Reconstruct
filtered_signal = basis.eigenvectors * filtered_coeffs

# Compute denoising quality
noise_reduction = norm(noisy_signal - signal) - norm(filtered_signal - signal)

println("  Original noise level: $(round(norm(noisy_signal - signal), digits=4))")
println("  After filtering: $(round(norm(filtered_signal - signal), digits=4))")
println("  Noise reduction: $(round(noise_reduction, digits=4))")
println()

println("=== Example Complete ===")
println()
println("Key insights:")
println("  - Lower eigenvalues → smoother eigenfunctions (global features)")
println("  - Higher eigenvalues → oscillatory eigenfunctions (local details)")
println("  - Spectral domain enables efficient filtering and compression")
println()
println("Applications in geometry:")
println("  - Shape matching and retrieval")
println("  - Mesh compression")
println("  - Feature extraction")
println("  - Surface smoothing and denoising")
