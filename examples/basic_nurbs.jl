"""
Basic NURBS Surface Example

Demonstrates:
- Creating a simple NURBS surface
- Evaluating points
- Computing normals and curvatures
- Grid evaluation for visualization
"""

using GeometryNervousSystem
using LinearAlgebra

println("=== Basic NURBS Surface Example ===\n")

# 1. Create a simple wavy surface
println("Creating wavy NURBS surface...")

degree = 3
u_res = 6
v_res = 6

# Generate control points with sinusoidal variation
control_points = zeros(u_res, v_res, 3)
for i in 1:u_res, j in 1:v_res
    x = (i - 1) / (u_res - 1)
    y = (j - 1) / (v_res - 1)
    z = 0.2 * sin(2π * x) * cos(2π * y)
    control_points[i, j, :] = [x, y, z]
end

# Uniform weights (for non-rational B-spline)
weights = ones(u_res, v_res)

# Create uniform knot vectors
knots_u = uniform_knot_vector(u_res, degree)
knots_v = uniform_knot_vector(v_res, degree)

# Construct surface
surface = NURBSSurface(degree, degree, control_points, weights, knots_u, knots_v)

println("✓ Surface created")
println("  Degree: ($degree, $degree)")
println("  Control points: $u_res × $v_res")
println()

# 2. Evaluate at specific points
println("Evaluating surface at key points...")

points_to_eval = [
    (0.0, 0.0, "Corner (0,0)"),
    (0.5, 0.5, "Center"),
    (1.0, 1.0, "Corner (1,1)"),
    (0.25, 0.75, "Arbitrary point"),
]

for (u, v, label) in points_to_eval
    point = evaluate(surface, u, v)
    println("  $label (u=$u, v=$v):")
    println("    → [$(round(point[1], digits=4)), $(round(point[2], digits=4)), $(round(point[3], digits=4))]")
end

println()

# 3. Compute normals and curvatures
println("Computing differential geometry at center...")

u_center = 0.5
v_center = 0.5

point = evaluate(surface, u_center, v_center)
normal = compute_normal(surface, u_center, v_center)
k1, k2 = compute_curvature(surface, u_center, v_center)

println("  Point: [$(round(point[1], digits=4)), $(round(point[2], digits=4)), $(round(point[3], digits=4))]")
println("  Normal: [$(round(normal[1], digits=4)), $(round(normal[2], digits=4)), $(round(normal[3], digits=4))]")
println("  Principal curvatures: κ₁=$(round(k1, digits=4)), κ₂=$(round(k2, digits=4))")
println("  Gaussian curvature: K=$(round(k1*k2, digits=4))")
println("  Mean curvature: H=$(round((k1+k2)/2, digits=4))")

println()

# 4. Batch evaluation
println("Batch evaluation (parallelized in Rust)...")

n_samples = 100
uv_pairs = hcat(
    rand(n_samples),
    rand(n_samples)
)

@time points = evaluate_batch(surface, uv_pairs)

println("  Evaluated $n_samples points")
println("  Result shape: $(size(points))")

println()

# 5. Grid evaluation for visualization
println("Grid evaluation for visualization...")

grid_res = 50
@time grid = evaluate_grid(surface, grid_res, grid_res)

println("  Grid: $grid_res × $grid_res")
println("  Total points: $(grid_res * grid_res)")

# Extract z-heights for statistics
z_vals = grid[:, :, 3]
println("\n  Z-height statistics:")
println("    Min:  $(round(minimum(z_vals), digits=4))")
println("    Max:  $(round(maximum(z_vals), digits=4))")
println("    Mean: $(round(sum(z_vals) / length(z_vals), digits=4))")

println()

# 6. Alternative calling syntax
println("Testing callable surface syntax...")

p1 = surface(0.3, 0.7)  # Can call surface directly
p2 = evaluate(surface, 0.3, 0.7)  # Equivalent

@assert p1 ≈ p2

println("  ✓ surface(u, v) works as shorthand for evaluate()")

println()
println("=== Example Complete ===")
println()
println("Next steps:")
println("  - Modify control points to create different shapes")
println("  - Experiment with different degrees")
println("  - Try non-uniform knot vectors for local refinement")
println("  - Export grid to visualization tool (e.g., Plots.jl, Makie.jl)")
