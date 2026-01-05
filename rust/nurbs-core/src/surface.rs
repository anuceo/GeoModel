use ndarray::{Array2, Array3};
use rayon::prelude::*;

/// NURBS surface representation
pub struct NURBSSurface {
    pub degree_u: usize,
    pub degree_v: usize,
    pub control_points: Array3<f64>, // [u_res, v_res, 3]
    pub weights: Array2<f64>,        // [u_res, v_res]
    pub knots_u: Vec<f64>,
    pub knots_v: Vec<f64>,
}

impl NURBSSurface {
    /// Create new NURBS surface
    pub fn new(
        degree_u: usize,
        degree_v: usize,
        control_points: Array3<f64>,
        weights: Array2<f64>,
        knots_u: Vec<f64>,
        knots_v: Vec<f64>,
    ) -> Self {
        // Validate inputs
        assert_eq!(control_points.shape()[2], 3, "Control points must be 3D");
        assert_eq!(
            control_points.shape()[0],
            weights.shape()[0],
            "Control points and weights must match in u dimension"
        );
        assert_eq!(
            control_points.shape()[1],
            weights.shape()[1],
            "Control points and weights must match in v dimension"
        );
        assert_eq!(
            knots_u.len(),
            control_points.shape()[0] + degree_u + 1,
            "Invalid knot vector length in u"
        );
        assert_eq!(
            knots_v.len(),
            control_points.shape()[1] + degree_v + 1,
            "Invalid knot vector length in v"
        );

        Self {
            degree_u,
            degree_v,
            control_points,
            weights,
            knots_u,
            knots_v,
        }
    }

    /// Evaluate surface at parameter (u, v)
    pub fn evaluate(&self, u: f64, v: f64) -> [f64; 3] {
        let u_res = self.control_points.shape()[0];
        let v_res = self.control_points.shape()[1];

        // Evaluate basis functions
        let mut basis_u = vec![0.0; u_res];
        let mut basis_v = vec![0.0; v_res];

        super::basis::CoxDeBoor::evaluate_all(u, &self.knots_u, self.degree_u, &mut basis_u);
        super::basis::CoxDeBoor::evaluate_all(v, &self.knots_v, self.degree_v, &mut basis_v);

        // Compute rational basis functions
        let mut weight_sum = 0.0;
        for i in 0..u_res {
            for j in 0..v_res {
                weight_sum += basis_u[i] * basis_v[j] * self.weights[[i, j]];
            }
        }

        let mut point = [0.0, 0.0, 0.0];

        for i in 0..u_res {
            for j in 0..v_res {
                let rational_basis = (basis_u[i] * basis_v[j] * self.weights[[i, j]]) / weight_sum;

                for k in 0..3 {
                    point[k] += rational_basis * self.control_points[[i, j, k]];
                }
            }
        }

        point
    }

    /// Batch evaluation (parallelized)
    pub fn evaluate_batch(&self, uv_pairs: &[[f64; 2]]) -> Vec<[f64; 3]> {
        uv_pairs
            .par_iter()
            .map(|&[u, v]| self.evaluate(u, v))
            .collect()
    }

    /// Evaluate on uniform grid (for tessellation)
    pub fn evaluate_grid(&self, u_samples: usize, v_samples: usize) -> Array3<f64> {
        let mut grid = Array3::zeros((u_samples, v_samples, 3));

        let u_step = 1.0 / (u_samples - 1) as f64;
        let v_step = 1.0 / (v_samples - 1) as f64;

        grid.axis_iter_mut(ndarray::Axis(0))
            .into_par_iter()
            .enumerate()
            .for_each(|(i, mut row)| {
                let u = i as f64 * u_step;

                for (j, mut elem) in row.axis_iter_mut(ndarray::Axis(0)).enumerate() {
                    let v = j as f64 * v_step;
                    let point = self.evaluate(u, v);

                    for k in 0..3 {
                        elem[k] = point[k];
                    }
                }
            });

        grid
    }

    /// Get control point at index (i, j)
    pub fn control_point(&self, i: usize, j: usize) -> [f64; 3] {
        [
            self.control_points[[i, j, 0]],
            self.control_points[[i, j, 1]],
            self.control_points[[i, j, 2]],
        ]
    }

    /// Get weight at index (i, j)
    pub fn weight(&self, i: usize, j: usize) -> f64 {
        self.weights[[i, j]]
    }

    /// Get dimensions
    pub fn dimensions(&self) -> (usize, usize) {
        (self.control_points.shape()[0], self.control_points.shape()[1])
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use approx::assert_relative_eq;

    fn create_flat_plane() -> NURBSSurface {
        let degree = 3;
        let u_res = 5;
        let v_res = 5;

        // Control points (flat plane at z=0)
        let mut control_points = Array3::zeros((u_res, v_res, 3));
        for i in 0..u_res {
            for j in 0..v_res {
                control_points[[i, j, 0]] = i as f64 / 4.0;
                control_points[[i, j, 1]] = j as f64 / 4.0;
                control_points[[i, j, 2]] = 0.0;
            }
        }

        // Uniform weights
        let weights = Array2::ones((u_res, v_res));

        // Uniform knot vectors
        let knots_u = vec![0.0, 0.0, 0.0, 0.0, 0.5, 1.0, 1.0, 1.0, 1.0];
        let knots_v = vec![0.0, 0.0, 0.0, 0.0, 0.5, 1.0, 1.0, 1.0, 1.0];

        NURBSSurface::new(degree, degree, control_points, weights, knots_u, knots_v)
    }

    #[test]
    fn test_evaluate_corners() {
        let surface = create_flat_plane();

        // Corner points
        let p00 = surface.evaluate(0.0, 0.0);
        let p10 = surface.evaluate(1.0, 0.0);
        let p01 = surface.evaluate(0.0, 1.0);
        let p11 = surface.evaluate(1.0, 1.0);

        assert_relative_eq!(p00[0], 0.0, epsilon = 1e-6);
        assert_relative_eq!(p00[1], 0.0, epsilon = 1e-6);

        assert_relative_eq!(p10[0], 1.0, epsilon = 1e-6);
        assert_relative_eq!(p10[1], 0.0, epsilon = 1e-6);

        assert_relative_eq!(p01[0], 0.0, epsilon = 1e-6);
        assert_relative_eq!(p01[1], 1.0, epsilon = 1e-6);

        assert_relative_eq!(p11[0], 1.0, epsilon = 1e-6);
        assert_relative_eq!(p11[1], 1.0, epsilon = 1e-6);
    }

    #[test]
    fn test_evaluate_center() {
        let surface = create_flat_plane();

        let point = surface.evaluate(0.5, 0.5);
        assert_relative_eq!(point[0], 0.5, epsilon = 1e-6);
        assert_relative_eq!(point[1], 0.5, epsilon = 1e-6);
        assert_relative_eq!(point[2], 0.0, epsilon = 1e-6);
    }

    #[test]
    fn test_batch_evaluation() {
        let surface = create_flat_plane();

        let uv_pairs = vec![[0.0, 0.0], [0.5, 0.5], [1.0, 1.0]];
        let points = surface.evaluate_batch(&uv_pairs);

        assert_eq!(points.len(), 3);
        assert_relative_eq!(points[1][0], 0.5, epsilon = 1e-6);
        assert_relative_eq!(points[1][1], 0.5, epsilon = 1e-6);
    }
}
