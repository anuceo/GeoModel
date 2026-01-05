//! Adaptive tessellation for NURBS surfaces
//!
//! This module will provide curvature-based adaptive tessellation
//! for efficient mesh generation from NURBS surfaces.

pub mod adaptive;
pub mod triangulation;

pub use adaptive::AdaptiveTessellator;
pub use triangulation::triangulate;

#[cfg(test)]
mod tests {
    #[test]
    fn placeholder_test() {
        assert!(true);
    }
}
