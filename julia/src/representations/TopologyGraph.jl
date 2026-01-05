"""
    TopologyGraph

Layer 3: B-Rep topology graph representation.

Represents the boundary representation structure: faces, edges, vertices,
and their adjacency relationships. Forms the bridge between spectral
geometry and explicit NURBS patches.
"""
module TopologyGraph

using Graphs
using DataStructures

export BRepTopology, Face, Edge, Vertex, add_face!, add_edge!, add_vertex!

"""
    Vertex

Topological vertex with associated geometric point.
"""
mutable struct Vertex
    id::Int
    position::Vector{Float64}  # Approximate position (will be refined)
end

"""
    Edge

Topological edge connecting two vertices.
"""
mutable struct Edge
    id::Int
    v1::Int
    v2::Int
    convex::Bool  # Convex or concave
end

"""
    Face

Topological face bounded by edges.
"""
mutable struct Face
    id::Int
    edges::Vector{Int}
    normal::Vector{Float64}  # Average normal direction
end

"""
    BRepTopology

Complete boundary representation topology.
"""
mutable struct BRepTopology
    vertices::Dict{Int, Vertex}
    edges::Dict{Int, Edge}
    faces::Dict{Int, Face}

    adjacency::SimpleGraph  # Face adjacency graph

    vertex_count::Int
    edge_count::Int
    face_count::Int

    function BRepTopology()
        new(
            Dict{Int, Vertex}(),
            Dict{Int, Edge}(),
            Dict{Int, Face}(),
            SimpleGraph(),
            0, 0, 0
        )
    end
end

"""
    add_vertex!(topo::BRepTopology, position::Vector{Float64})

Add a vertex to the topology.
"""
function add_vertex!(topo::BRepTopology, position::Vector{Float64})
    topo.vertex_count += 1
    v = Vertex(topo.vertex_count, position)
    topo.vertices[topo.vertex_count] = v
    return topo.vertex_count
end

"""
    add_edge!(topo::BRepTopology, v1::Int, v2::Int, convex::Bool=true)

Add an edge between two vertices.
"""
function add_edge!(topo::BRepTopology, v1::Int, v2::Int, convex::Bool=true)
    @assert haskey(topo.vertices, v1) "Vertex $v1 does not exist"
    @assert haskey(topo.vertices, v2) "Vertex $v2 does not exist"

    topo.edge_count += 1
    e = Edge(topo.edge_count, v1, v2, convex)
    topo.edges[topo.edge_count] = e
    return topo.edge_count
end

"""
    add_face!(topo::BRepTopology, edges::Vector{Int}, normal::Vector{Float64})

Add a face bounded by edges.
"""
function add_face!(topo::BRepTopology, edges::Vector{Int}, normal::Vector{Float64})
    for e_id in edges
        @assert haskey(topo.edges, e_id) "Edge $e_id does not exist"
    end

    topo.face_count += 1
    f = Face(topo.face_count, edges, normal)
    topo.faces[topo.face_count] = f

    # Update adjacency graph
    add_vertex!(topo.adjacency)

    return topo.face_count
end

end # module TopologyGraph
