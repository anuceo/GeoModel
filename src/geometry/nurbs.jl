"""
    NURBSSurface

High-level NURBS surface representation with Julia-friendly interface.

Wraps the high-performance Rust kernel via FFI for evaluation,
while providing clean Julia semantics for creation and manipulation.
"""
struct NURBSSurface
    degree_u::Int
    degree_v::Int
    control_points::Array{Float64, 3}  # [u_res, v_res, 3]
    weights::Matrix{Float64}           # [u_res, v_res]
    knots_u::Vector{Float64}
    knots_v::Vector{Float64}

    # Cached Rust handle
    rust_handle::RustBridge.NURBSSurfaceHandle

    """
        NURBSSurface(degree_u, degree_v, control_points, weights, knots_u, knots_v)

    Create NURBS surface from control points and knot vectors.

    # Arguments
    - `degree_u::Int`: Polynomial degree in u direction
    - `degree_v::Int`: Polynomial degree in v direction
    - `control_points::Array{Float64, 3}`: Control net [u_res × v_res × 3]
    - `weights::Matrix{Float64}`: Rational weights [u_res × v_res]
    - `knots_u::Vector{Float64}`: Knot vector in u (length = u_res + degree_u + 1)
    - `knots_v::Vector{Float64}`: Knot vector in v (length = v_res + degree_v + 1)

    # Example
    ```julia
    # Create a simple bicubic patch
    degree = 3
    cp = zeros(5, 5, 3)
    for i in 1:5, j in 1:5
        cp[i, j, :] = [(i-1)/4, (j-1)/4, sin(i*j/10)]
    end

    weights = ones(5, 5)
    knots = [0, 0, 0, 0, 0.5, 1, 1, 1, 1]

    surface = NURBSSurface(degree, degree, cp, weights, knots, knots)
    ```
    """
    function NURBSSurface(degree_u, degree_v, control_points, weights, knots_u, knots_v)
        # Validate inputs
        @assert size(control_points, 3) == 3 "Control points must be 3D"
        @assert size(control_points)[1:2] == size(weights) "Control points and weights must match"
        @assert length(knots_u) == size(control_points, 1) + degree_u + 1 "Invalid u knot vector length"
        @assert length(knots_v) == size(control_points, 2) + degree_v + 1 "Invalid v knot vector length"

        # Check knot vector validity
        @assert issorted(knots_u) "Knot vector u must be non-decreasing"
        @assert issorted(knots_v) "Knot vector v must be non-decreasing"

        # Create Rust handle
        handle = RustBridge.nurbs_create(
            degree_u, degree_v, control_points, weights, knots_u, knots_v
        )

        new(degree_u, degree_v, control_points, weights, knots_u, knots_v, handle)
    end
end

"""
    evaluate(surface::NURBSSurface, u, v)

Evaluate NURBS surface at parametric coordinates (u, v).

# Arguments
- `surface::NURBSSurface`: The surface to evaluate
- `u::Real`: Parameter in u direction ∈ [0, 1]
- `v::Real`: Parameter in v direction ∈ [0, 1]

# Returns
- `Vector{Float64}`: 3D point [x, y, z]

# Example
```julia
surface = NURBSSurface(...)
point = evaluate(surface, 0.5, 0.5)  # Center of surface
```
"""
function evaluate(surface::NURBSSurface, u::Real, v::Real)
    @assert 0 <= u <= 1 "u must be in [0, 1]"
    @assert 0 <= v <= 1 "v must be in [0, 1]"
    return RustBridge.nurbs_evaluate(surface.rust_handle, Float64(u), Float64(v))
end

"""
    evaluate_batch(surface::NURBSSurface, uv_pairs)

Batch evaluation for multiple (u, v) parameter pairs (parallelized).

# Arguments
- `surface::NURBSSurface`: The surface to evaluate
- `uv_pairs::Matrix{<:Real}`: Parameter pairs [n × 2]

# Returns
- `Matrix{Float64}`: Points [n × 3]

# Example
```julia
uv = [0.0 0.0; 0.5 0.5; 1.0 1.0]
points = evaluate_batch(surface, uv)
```
"""
function evaluate_batch(surface::NURBSSurface, uv_pairs::Matrix{<:Real})
    @assert size(uv_pairs, 2) == 2 "uv_pairs must be [n × 2]"
    return RustBridge.nurbs_evaluate_batch(surface.rust_handle, Float64.(uv_pairs))
end

"""
    evaluate_grid(surface::NURBSSurface, u_samples::Int, v_samples::Int)

Evaluate surface on a uniform parametric grid.

# Arguments
- `surface::NURBSSurface`: The surface to evaluate
- `u_samples::Int`: Number of samples in u direction
- `v_samples::Int`: Number of samples in v direction

# Returns
- `Array{Float64, 3}`: Grid of points [u_samples × v_samples × 3]

# Example
```julia
grid = evaluate_grid(surface, 100, 100)  # 100×100 mesh
```
"""
function evaluate_grid(surface::NURBSSurface, u_samples::Int, v_samples::Int)
    @assert u_samples >= 2 "Need at least 2 samples in u"
    @assert v_samples >= 2 "Need at least 2 samples in v"
    return RustBridge.nurbs_evaluate_grid(surface.rust_handle, u_samples, v_samples)
end

"""
    compute_normal(surface::NURBSSurface, u, v)

Compute unit surface normal at (u, v).

# Arguments
- `surface::NURBSSurface`: The surface
- `u::Real`: Parameter in u direction ∈ [0, 1]
- `v::Real`: Parameter in v direction ∈ [0, 1]

# Returns
- `Vector{Float64}`: Unit normal vector [nx, ny, nz]

# Example
```julia
normal = compute_normal(surface, 0.5, 0.5)
```
"""
function compute_normal(surface::NURBSSurface, u::Real, v::Real)
    @assert 0 <= u <= 1 "u must be in [0, 1]"
    @assert 0 <= v <= 1 "v must be in [0, 1]"
    return RustBridge.nurbs_normal(surface.rust_handle, Float64(u), Float64(v))
end

"""
    compute_curvature(surface::NURBSSurface, u, v)

Compute principal curvatures at (u, v).

# Arguments
- `surface::NURBSSurface`: The surface
- `u::Real`: Parameter in u direction ∈ [0, 1]
- `v::Real`: Parameter in v direction ∈ [0, 1]

# Returns
- `Tuple{Float64, Float64}`: Principal curvatures (κ₁, κ₂)

# Example
```julia
k1, k2 = compute_curvature(surface, 0.5, 0.5)
gaussian_curvature = k1 * k2
mean_curvature = (k1 + k2) / 2
```
"""
function compute_curvature(surface::NURBSSurface, u::Real, v::Real)
    @assert 0 <= u <= 1 "u must be in [0, 1]"
    @assert 0 <= v <= 1 "v must be in [0, 1]"
    return RustBridge.nurbs_curvature(surface.rust_handle, Float64(u), Float64(v))
end

# Utility functions

"""
    uniform_knot_vector(n::Int, degree::Int)

Generate a uniform (open) knot vector.

# Arguments
- `n::Int`: Number of control points
- `degree::Int`: Polynomial degree

# Returns
- `Vector{Float64}`: Knot vector of length n + degree + 1
"""
function uniform_knot_vector(n::Int, degree::Int)
    knots = zeros(n + degree + 1)

    # First (degree + 1) knots are 0
    # Last (degree + 1) knots are 1
    # Interior knots are uniformly spaced

    for i in 1:(degree + 1)
        knots[i] = 0.0
        knots[end - i + 1] = 1.0
    end

    interior_count = n - degree - 1
    if interior_count > 0
        for i in 1:interior_count
            knots[degree + 1 + i] = i / (interior_count + 1)
        end
    end

    return knots
end

"""
    dimensions(surface::NURBSSurface)

Get control net dimensions.

# Returns
- `Tuple{Int, Int}`: (u_res, v_res)
"""
function dimensions(surface::NURBSSurface)
    return size(surface.control_points)[1:2]
end

# Callable surface (for convenience)
(surface::NURBSSurface)(u::Real, v::Real) = evaluate(surface, u, v)
