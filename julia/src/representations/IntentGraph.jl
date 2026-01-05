"""
    IntentGraph

Layer 1: High-level design intent representation.

Captures user requirements as a graph structure with nodes representing
design primitives and edges representing relationships/constraints.
"""
module IntentGraph

using Graphs
using MetaGraphs

export DesignIntent, add_primitive!, add_constraint!

"""
    DesignIntent

Graph-based representation of design intent.
"""
mutable struct DesignIntent
    graph::MetaDiGraph
    primitive_count::Int
    constraint_count::Int

    function DesignIntent()
        new(MetaDiGraph(), 0, 0)
    end
end

"""
    add_primitive!(intent::DesignIntent, type::Symbol, properties::Dict)

Add a design primitive (e.g., :hole, :fillet, :boss) to the intent graph.
"""
function add_primitive!(intent::DesignIntent, type::Symbol, properties::Dict)
    intent.primitive_count += 1
    add_vertex!(intent.graph)
    set_props!(intent.graph, intent.primitive_count, Dict(:type => type, :properties => properties))
    return intent.primitive_count
end

"""
    add_constraint!(intent::DesignIntent, from::Int, to::Int, constraint::Symbol)

Add a constraint edge between primitives.
"""
function add_constraint!(intent::DesignIntent, from::Int, to::Int, constraint::Symbol)
    add_edge!(intent.graph, from, to)
    set_props!(intent.graph, from, to, Dict(:constraint => constraint))
    intent.constraint_count += 1
end

end # module IntentGraph
