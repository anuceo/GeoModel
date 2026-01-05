//! High-performance NURBS evaluation kernel
//! Exposes C-compatible FFI for Julia interop

pub mod basis;
pub mod surface;
pub mod derivatives;
pub mod ffi;

pub use basis::CoxDeBoor;
pub use surface::NURBSSurface;
pub use derivatives::{compute_tangent, compute_normal, compute_curvature};

#[cfg(test)]
mod tests {
    use super::*;
    use approx::assert_relative_eq;

    #[test]
    fn test_basis_partition_of_unity() {
        let knots = vec![0.0, 0.0, 0.0, 0.0, 0.5, 1.0, 1.0, 1.0, 1.0];
        let degree = 3;
        let t = 0.5;

        let mut basis = vec![0.0; 5];
        CoxDeBoor::evaluate_all(t, &knots, degree, &mut basis);

        let sum: f64 = basis.iter().sum();
        assert_relative_eq!(sum, 1.0, epsilon = 1e-10);
    }

    #[test]
    fn test_basis_non_negativity() {
        let knots = vec![0.0, 0.0, 0.0, 0.0, 0.5, 1.0, 1.0, 1.0, 1.0];
        let degree = 3;

        for t in [0.0, 0.25, 0.5, 0.75, 1.0] {
            let mut basis = vec![0.0; 5];
            CoxDeBoor::evaluate_all(t, &knots, degree, &mut basis);

            for &b in &basis {
                assert!(b >= 0.0, "Basis function is negative at t={}", t);
            }
        }
    }
}
