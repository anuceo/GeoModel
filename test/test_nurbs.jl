using Test
using GeometryNervousSystem
using LinearAlgebra

@testset "NURBS Surface Creation and Evaluation" begin
    # Create a simple flat plane
    degree = 3
    u_res = 5
    v_res = 5

    # Control points (flat plane at z=0)
    control_points = zeros(u_res, v_res, 3)
    for i in 1:u_res, j in 1:v_res
        control_points[i, j, :] = [(i-1)/4, (j-1)/4, 0.0]
    end

    # Uniform weights
    weights = ones(u_res, v_res)

    # Uniform knot vectors
    knots_u = [0.0, 0.0, 0.0, 0.0, 0.5, 1.0, 1.0, 1.0, 1.0]
    knots_v = [0.0, 0.0, 0.0, 0.0, 0.5, 1.0, 1.0, 1.0, 1.0]

    @testset "Surface Construction" begin
        surface = NURBSSurface(degree, degree, control_points, weights, knots_u, knots_v)
        @test surface.degree_u == degree
        @test surface.degree_v == degree
        @test size(surface.control_points) == (u_res, v_res, 3)
    end

    surface = NURBSSurface(degree, degree, control_points, weights, knots_u, knots_v)

    @testset "Single Point Evaluation" begin
        # Center point
        point = evaluate(surface, 0.5, 0.5)
        @test length(point) == 3
        @test isapprox(point[1], 0.5, atol=1e-6)
        @test isapprox(point[2], 0.5, atol=1e-6)
        @test isapprox(point[3], 0.0, atol=1e-6)

        # Corner points
        p00 = evaluate(surface, 0.0, 0.0)
        @test isapprox(p00[1], 0.0, atol=1e-6)
        @test isapprox(p00[2], 0.0, atol=1e-6)

        p11 = evaluate(surface, 1.0, 1.0)
        @test isapprox(p11[1], 1.0, atol=1e-6)
        @test isapprox(p11[2], 1.0, atol=1e-6)
    end

    @testset "Callable Surface" begin
        # Test that surface can be called directly
        point = surface(0.5, 0.5)
        @test isapprox(point[1], 0.5, atol=1e-6)
    end

    @testset "Batch Evaluation" begin
        uv_pairs = [0.0 0.0; 0.5 0.5; 1.0 1.0]
        points = evaluate_batch(surface, uv_pairs)

        @test size(points) == (3, 3)
        @test isapprox(points[1, 1], 0.0, atol=1e-6)
        @test isapprox(points[2, 1], 0.5, atol=1e-6)
        @test isapprox(points[3, 1], 1.0, atol=1e-6)
    end

    @testset "Grid Evaluation" begin
        grid = evaluate_grid(surface, 10, 10)
        @test size(grid) == (10, 10, 3)

        # Check corners
        @test isapprox(grid[1, 1, 1], 0.0, atol=1e-6)
        @test isapprox(grid[10, 10, 1], 1.0, atol=1e-6)
    end

    @testset "Normal Computation" begin
        # Flat plane → normal should be [0, 0, ±1]
        normal = compute_normal(surface, 0.5, 0.5)
        @test length(normal) == 3
        @test isapprox(norm(normal), 1.0, atol=1e-6)  # Unit vector
        @test isapprox(abs(normal[3]), 1.0, atol=1e-3)  # Perpendicular to xy plane
        @test isapprox(normal[1], 0.0, atol=1e-3)
        @test isapprox(normal[2], 0.0, atol=1e-3)
    end

    @testset "Curvature Computation" begin
        k1, k2 = compute_curvature(surface, 0.5, 0.5)

        # Flat plane → zero curvature
        @test isapprox(k1, 0.0, atol=1e-2)
        @test isapprox(k2, 0.0, atol=1e-2)
    end
end

@testset "NURBS Wavy Surface" begin
    # Create a more interesting surface
    degree = 3
    u_res = 6
    v_res = 6

    control_points = zeros(u_res, v_res, 3)
    for i in 1:u_res, j in 1:v_res
        x = (i - 1) / (u_res - 1)
        y = (j - 1) / (v_res - 1)
        z = 0.1 * sin(2π * x) * cos(2π * y)
        control_points[i, j, :] = [x, y, z]
    end

    weights = ones(u_res, v_res)
    knots = [0.0, 0.0, 0.0, 0.0, 0.33, 0.67, 1.0, 1.0, 1.0, 1.0]

    surface = NURBSSurface(degree, degree, control_points, weights, knots, knots)

    @testset "Wavy Surface Evaluation" begin
        point = evaluate(surface, 0.5, 0.5)
        @test length(point) == 3
        # Just check it doesn't crash
    end

    @testset "Wavy Surface Normal" begin
        normal = compute_normal(surface, 0.5, 0.5)
        @test isapprox(norm(normal), 1.0, atol=1e-6)
    end
end

@testset "Utility Functions" begin
    @testset "Uniform Knot Vector" begin
        knots = uniform_knot_vector(5, 3)
        @test length(knots) == 5 + 3 + 1
        @test knots[1] == 0.0
        @test knots[end] == 1.0
        @test issorted(knots)
    end
end
