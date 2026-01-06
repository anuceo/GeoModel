using Test
using GeometryNervousSystem

@testset "Full Pipeline Integration" begin
    @testset "Intent Graph Creation" begin
        intent = IntentGraph.DesignIntent()

        # Add some primitives
        hole_id = IntentGraph.add_primitive!(intent, :hole, Dict(:diameter => 5.0))
        boss_id = IntentGraph.add_primitive!(intent, :boss, Dict(:height => 10.0))

        @test intent.primitive_count == 2
        @test hole_id == 1
        @test boss_id == 2

        # Add constraint
        IntentGraph.add_constraint!(intent, hole_id, boss_id, :concentric)
        @test intent.constraint_count == 1
    end

    @testset "Topology Graph Construction" begin
        topo = TopologyGraph.BRepTopology()

        # Add vertices
        v1 = TopologyGraph.add_vertex!(topo, [0.0, 0.0, 0.0])
        v2 = TopologyGraph.add_vertex!(topo, [1.0, 0.0, 0.0])
        v3 = TopologyGraph.add_vertex!(topo, [1.0, 1.0, 0.0])
        v4 = TopologyGraph.add_vertex!(topo, [0.0, 1.0, 0.0])

        @test topo.vertex_count == 4

        # Add edges
        e1 = TopologyGraph.add_edge!(topo, v1, v2)
        e2 = TopologyGraph.add_edge!(topo, v2, v3)
        e3 = TopologyGraph.add_edge!(topo, v3, v4)
        e4 = TopologyGraph.add_edge!(topo, v4, v1)

        @test topo.edge_count == 4

        # Add face
        f1 = TopologyGraph.add_face!(topo, [e1, e2, e3, e4], [0.0, 0.0, 1.0])
        @test topo.face_count == 1
    end

    @testset "Patch Assembly" begin
        # Create two simple NURBS surfaces
        degree = 2
        u_res = 3
        v_res = 3

        cp1 = zeros(u_res, v_res, 3)
        for i in 1:u_res, j in 1:v_res
            cp1[i, j, :] = [(i-1), (j-1), 0.0]
        end

        cp2 = zeros(u_res, v_res, 3)
        for i in 1:u_res, j in 1:v_res
            cp2[i, j, :] = [(i-1), (j-1), 1.0]
        end

        weights = ones(u_res, v_res)
        knots = [0.0, 0.0, 0.0, 1.0, 1.0, 1.0]

        surface1 = NURBSSurface(degree, degree, cp1, weights, knots, knots)
        surface2 = NURBSSurface(degree, degree, cp2, weights, knots, knots)

        # Create patch assembly
        assembly = SplinePatch.PatchAssembly()

        id1 = SplinePatch.add_patch!(assembly, surface1)
        id2 = SplinePatch.add_patch!(assembly, surface2)

        @test assembly.patch_count == 2
        @test id1 == 1
        @test id2 == 2

        # Add boundary constraint
        boundary = SplinePatch.PatchBoundary(
            id1, id2, :u_max, :u_min, SplinePatch.G0
        )
        SplinePatch.add_boundary!(assembly, boundary)

        @test length(assembly.boundaries) == 1

        # Validate
        @test SplinePatch.validate_assembly(assembly)
    end

    @testset "End-to-End Surface Generation" begin
        # This is a simplified version of the full pipeline
        # In practice, this would involve:
        # 1. Intent encoding
        # 2. Harmonic prediction
        # 3. Topology generation
        # 4. NURBS fitting
        # 5. Continuity enforcement

        # For now, just check we can create and evaluate a surface
        degree = 3
        u_res = 5
        v_res = 5

        control_points = zeros(u_res, v_res, 3)
        for i in 1:u_res, j in 1:v_res
            control_points[i, j, :] = [(i-1)/4, (j-1)/4, 0.0]
        end

        weights = ones(u_res, v_res)
        knots = uniform_knot_vector(u_res, degree)

        surface = NURBSSurface(degree, degree, control_points, weights, knots, knots)

        # Evaluate at multiple points
        grid = evaluate_grid(surface, 20, 20)
        @test size(grid) == (20, 20, 3)

        # Compute normals at grid points
        normals = [compute_normal(surface, u, v)
                   for u in range(0, 1, length=5)
                   for v in range(0, 1, length=5)]

        @test length(normals) == 25
        @test all(n -> isapprox(norm(n), 1.0, atol=1e-6), normals)
    end
end
