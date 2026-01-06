"""
    RustBridge

FFI interface to Rust NURBS kernel

Provides zero-cost interop between Julia and Rust for high-performance
NURBS evaluation, normal computation, and curvature analysis.
"""
module RustBridge

using Libdl

# Load Rust library
const NURBS_LIB = let
    lib_path = joinpath(@__DIR__, "..", "lib")
    if Sys.iswindows()
        joinpath(lib_path, "nurbs_core.dll")
    elseif Sys.isapple()
        joinpath(lib_path, "libnurbs_core.dylib")
    else
        joinpath(lib_path, "libnurbs_core.so")
    end
end

# Check if library exists
function check_library()
    if !isfile(NURBS_LIB)
        error("""
        Rust NURBS library not found at: $NURBS_LIB

        Please build the Rust library first:
            cargo build --release --workspace

        Then copy the library to julia/lib/:
            mkdir -p julia/lib
            cp target/release/libnurbs_core.* julia/lib/
        """)
    end
end

# Opaque handle type
mutable struct NURBSSurfaceHandle
    ptr::Ptr{Cvoid}

    function NURBSSurfaceHandle(ptr::Ptr{Cvoid})
        if ptr == C_NULL
            error("Failed to create NURBS surface (null pointer returned)")
        end
        handle = new(ptr)
        finalizer(nurbs_free, handle)
        return handle
    end
end

"""
    nurbs_create(degree_u, degree_v, control_points, weights, knots_u, knots_v)

Create NURBS surface from Julia arrays via FFI to Rust kernel.

# Arguments
- `degree_u::Int`: Degree in u direction
- `degree_v::Int`: Degree in v direction
- `control_points::Array{Float64, 3}`: Control points [u_res × v_res × 3]
- `weights::Matrix{Float64}`: Weights [u_res × v_res]
- `knots_u::Vector{Float64}`: Knot vector in u direction
- `knots_v::Vector{Float64}`: Knot vector in v direction

# Returns
- `NURBSSurfaceHandle`: Opaque handle to Rust surface object
"""
function nurbs_create(
    degree_u::Int,
    degree_v::Int,
    control_points::Array{Float64, 3},
    weights::Matrix{Float64},
    knots_u::Vector{Float64},
    knots_v::Vector{Float64}
)
    check_library()

    u_res, v_res, dim = size(control_points)

    @assert dim == 3 "Control points must be 3D"
    @assert size(weights) == (u_res, v_res) "Weights must match control points dimensions"
    @assert length(knots_u) == u_res + degree_u + 1 "Invalid knot vector length in u"
    @assert length(knots_v) == v_res + degree_v + 1 "Invalid knot vector length in v"

    # Flatten control points (Rust expects row-major, Julia is column-major)
    # We need to transpose the memory layout
    cp_flat = vec(permutedims(control_points, [3, 2, 1]))
    w_flat = vec(weights')

    ptr = ccall(
        (:nurbs_create, NURBS_LIB),
        Ptr{Cvoid},
        (Cint, Cint, Cint, Cint, Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Ptr{Float64}, Cint, Cint),
        degree_u, degree_v, u_res, v_res,
        cp_flat, w_flat, knots_u, knots_v,
        length(knots_u), length(knots_v)
    )

    return NURBSSurfaceHandle(ptr)
end

"""
    nurbs_evaluate(handle, u, v)

Evaluate NURBS surface at parameter (u, v)

# Arguments
- `handle::NURBSSurfaceHandle`: Surface handle from nurbs_create
- `u::Float64`: Parameter in u direction [0, 1]
- `v::Float64`: Parameter in v direction [0, 1]

# Returns
- `Vector{Float64}`: Point [x, y, z]
"""
function nurbs_evaluate(handle::NURBSSurfaceHandle, u::Float64, v::Float64)
    output = zeros(Float64, 3)

    ccall(
        (:nurbs_evaluate, NURBS_LIB),
        Cvoid,
        (Ptr{Cvoid}, Float64, Float64, Ptr{Float64}),
        handle.ptr, u, v, output
    )

    return output
end

"""
    nurbs_evaluate_batch(handle, uv_pairs)

Batch evaluation of NURBS surface (parallelized in Rust)

# Arguments
- `handle::NURBSSurfaceHandle`: Surface handle
- `uv_pairs::Matrix{Float64}`: UV parameters [n × 2]

# Returns
- `Matrix{Float64}`: Points [n × 3]
"""
function nurbs_evaluate_batch(handle::NURBSSurfaceHandle, uv_pairs::Matrix{Float64})
    n = size(uv_pairs, 1)
    @assert size(uv_pairs, 2) == 2 "uv_pairs must be [n × 2]"

    output = zeros(Float64, n * 3)

    ccall(
        (:nurbs_evaluate_batch, NURBS_LIB),
        Cvoid,
        (Ptr{Cvoid}, Ptr{Float64}, Cint, Ptr{Float64}),
        handle.ptr, vec(uv_pairs'), n, output
    )

    return reshape(output, 3, n)'
end

"""
    nurbs_evaluate_grid(handle, u_samples, v_samples)

Evaluate surface on uniform grid

# Arguments
- `handle::NURBSSurfaceHandle`: Surface handle
- `u_samples::Int`: Number of samples in u direction
- `v_samples::Int`: Number of samples in v direction

# Returns
- `Array{Float64, 3}`: Grid of points [u_samples × v_samples × 3]
"""
function nurbs_evaluate_grid(handle::NURBSSurfaceHandle, u_samples::Int, v_samples::Int)
    output = zeros(Float64, u_samples * v_samples * 3)

    ccall(
        (:nurbs_evaluate_grid, NURBS_LIB),
        Cvoid,
        (Ptr{Cvoid}, Cint, Cint, Ptr{Float64}),
        handle.ptr, u_samples, v_samples, output
    )

    return reshape(output, 3, v_samples, u_samples) |>
           x -> permutedims(x, [3, 2, 1])
end

"""
    nurbs_normal(handle, u, v)

Compute surface normal at (u, v)

# Arguments
- `handle::NURBSSurfaceHandle`: Surface handle
- `u::Float64`: Parameter in u direction
- `v::Float64`: Parameter in v direction

# Returns
- `Vector{Float64}`: Unit normal vector [nx, ny, nz]
"""
function nurbs_normal(handle::NURBSSurfaceHandle, u::Float64, v::Float64)
    output = zeros(Float64, 3)

    ccall(
        (:nurbs_normal, NURBS_LIB),
        Cvoid,
        (Ptr{Cvoid}, Float64, Float64, Ptr{Float64}),
        handle.ptr, u, v, output
    )

    return output
end

"""
    nurbs_curvature(handle, u, v)

Compute principal curvatures at (u, v)

# Arguments
- `handle::NURBSSurfaceHandle`: Surface handle
- `u::Float64`: Parameter in u direction
- `v::Float64`: Parameter in v direction

# Returns
- `Tuple{Float64, Float64}`: Principal curvatures (k1, k2)
"""
function nurbs_curvature(handle::NURBSSurfaceHandle, u::Float64, v::Float64)
    output = zeros(Float64, 2)

    ccall(
        (:nurbs_curvature, NURBS_LIB),
        Cvoid,
        (Ptr{Cvoid}, Float64, Float64, Ptr{Float64}),
        handle.ptr, u, v, output
    )

    return (output[1], output[2])
end

"""
    nurbs_free(handle)

Free NURBS surface (called automatically by finalizer)
"""
function nurbs_free(handle::NURBSSurfaceHandle)
    if handle.ptr != C_NULL
        ccall(
            (:nurbs_free, NURBS_LIB),
            Cvoid,
            (Ptr{Cvoid},),
            handle.ptr
        )
        handle.ptr = C_NULL
    end
end

end # module RustBridge
