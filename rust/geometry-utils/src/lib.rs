//! Shared geometry utilities
//!
//! Common vector and matrix operations for geometric algorithms

pub mod vector;
pub mod matrix;

pub use vector::{Vec3, dot, cross, normalize};
pub use matrix::Mat3;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_vec3_creation() {
        let v = Vec3::new(1.0, 2.0, 3.0);
        assert_eq!(v.x, 1.0);
        assert_eq!(v.y, 2.0);
        assert_eq!(v.z, 3.0);
    }
}
