use crate::surface::NURBSSurface;

/// Compute tangent vectors at a surface point
pub fn compute_tangent(surface: &NURBSSurface, u: f64, v: f64) -> ([f64; 3], [f64; 3]) {
    let eps = 1e-6;

    // Numerical differentiation (central difference)
    let u_plus = surface.evaluate((u + eps).min(1.0), v);
    let u_minus = surface.evaluate((u - eps).max(0.0), v);

    let v_plus = surface.evaluate(u, (v + eps).min(1.0));
    let v_minus = surface.evaluate(u, (v - eps).max(0.0));

    let du = [
        (u_plus[0] - u_minus[0]) / (2.0 * eps),
        (u_plus[1] - u_minus[1]) / (2.0 * eps),
        (u_plus[2] - u_minus[2]) / (2.0 * eps),
    ];

    let dv = [
        (v_plus[0] - v_minus[0]) / (2.0 * eps),
        (v_plus[1] - v_minus[1]) / (2.0 * eps),
        (v_plus[2] - v_minus[2]) / (2.0 * eps),
    ];

    (du, dv)
}

/// Compute surface normal at a point
pub fn compute_normal(surface: &NURBSSurface, u: f64, v: f64) -> [f64; 3] {
    let (du, dv) = compute_tangent(surface, u, v);

    // Cross product
    let normal = [
        du[1] * dv[2] - du[2] * dv[1],
        du[2] * dv[0] - du[0] * dv[2],
        du[0] * dv[1] - du[1] * dv[0],
    ];

    // Normalize
    let length = (normal[0].powi(2) + normal[1].powi(2) + normal[2].powi(2)).sqrt();

    if length > 1e-10 {
        [normal[0] / length, normal[1] / length, normal[2] / length]
    } else {
        [0.0, 0.0, 1.0] // Degenerate case
    }
}

/// Compute principal curvatures and directions
pub fn compute_curvature(surface: &NURBSSurface, u: f64, v: f64) -> (f64, f64) {
    // Numerical differentiation (central differences).
    //
    // This epsilon is intentionally larger than compute_tangent's default to avoid
    // catastrophic cancellation when estimating second derivatives.
    let eps = 1e-3;

    let u_p = (u + eps).min(1.0);
    let u_m = (u - eps).max(0.0);
    let v_p = (v + eps).min(1.0);
    let v_m = (v - eps).max(0.0);

    // First derivatives
    let u_plus = surface.evaluate(u_p, v);
    let u_minus = surface.evaluate(u_m, v);
    let v_plus = surface.evaluate(u, v_p);
    let v_minus = surface.evaluate(u, v_m);

    let du = [
        (u_plus[0] - u_minus[0]) / (2.0 * eps),
        (u_plus[1] - u_minus[1]) / (2.0 * eps),
        (u_plus[2] - u_minus[2]) / (2.0 * eps),
    ];

    let dv = [
        (v_plus[0] - v_minus[0]) / (2.0 * eps),
        (v_plus[1] - v_minus[1]) / (2.0 * eps),
        (v_plus[2] - v_minus[2]) / (2.0 * eps),
    ];

    // Second derivatives
    let p = surface.evaluate(u, v);

    let u_plus_v_plus = surface.evaluate(u_p, v_p);
    let u_plus_v_minus = surface.evaluate(u_p, v_m);
    let u_minus_v_plus = surface.evaluate(u_m, v_p);
    let u_minus_v_minus = surface.evaluate(u_m, v_m);

    let duu = [
        (u_plus[0] - 2.0 * p[0] + u_minus[0]) / (eps * eps),
        (u_plus[1] - 2.0 * p[1] + u_minus[1]) / (eps * eps),
        (u_plus[2] - 2.0 * p[2] + u_minus[2]) / (eps * eps),
    ];

    let dvv = [
        (v_plus[0] - 2.0 * p[0] + v_minus[0]) / (eps * eps),
        (v_plus[1] - 2.0 * p[1] + v_minus[1]) / (eps * eps),
        (v_plus[2] - 2.0 * p[2] + v_minus[2]) / (eps * eps),
    ];

    let duv = [
        (u_plus_v_plus[0] - u_plus_v_minus[0] - u_minus_v_plus[0] + u_minus_v_minus[0])
            / (4.0 * eps * eps),
        (u_plus_v_plus[1] - u_plus_v_minus[1] - u_minus_v_plus[1] + u_minus_v_minus[1])
            / (4.0 * eps * eps),
        (u_plus_v_plus[2] - u_plus_v_minus[2] - u_minus_v_plus[2] + u_minus_v_minus[2])
            / (4.0 * eps * eps),
    ];

    // Normal vector
    let n = compute_normal(surface, u, v);

    // Coefficients of the first fundamental form
    let e = dot(&du, &du);
    let f = dot(&du, &dv);
    let g = dot(&dv, &dv);

    // Coefficients of the second fundamental form
    let l = dot(&duu, &n);
    let m = dot(&duv, &n);
    let n_coef = dot(&dvv, &n);

    // Gaussian and mean curvature
    let denom = e * g - f * f;
    if denom.abs() < 1e-14 {
        // Degenerate parameterization (e.g., near singularities).
        return (0.0, 0.0);
    }

    let k_gaussian = (l * n_coef - m * m) / denom;
    let k_mean = (e * n_coef - 2.0 * f * m + g * l) / (2.0 * denom);

    // Principal curvatures
    let discriminant = (k_mean * k_mean - k_gaussian).max(0.0).sqrt();
    let k1 = k_mean + discriminant;
    let k2 = k_mean - discriminant;

    (k1, k2)
}

/// Dot product of 3D vectors
fn dot(a: &[f64; 3], b: &[f64; 3]) -> f64 {
    a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
}

#[cfg(test)]
mod tests {
    use super::*;
    use approx::assert_relative_eq;
    use ndarray::{Array2, Array3};

    fn create_flat_surface() -> NURBSSurface {
        let degree = 1;
        let u_res = 2;
        let v_res = 2;

        // Unit square in the xy-plane (z = 0)
        let mut control_points = Array3::zeros((u_res, v_res, 3));
        control_points[[0, 0, 0]] = 0.0;
        control_points[[0, 0, 1]] = 0.0;
        control_points[[0, 1, 0]] = 0.0;
        control_points[[0, 1, 1]] = 1.0;
        control_points[[1, 0, 0]] = 1.0;
        control_points[[1, 0, 1]] = 0.0;
        control_points[[1, 1, 0]] = 1.0;
        control_points[[1, 1, 1]] = 1.0;

        let weights = Array2::ones((u_res, v_res));
        let knots = vec![0.0, 0.0, 1.0, 1.0];

        NURBSSurface::new(degree, degree, control_points, weights, knots.clone(), knots)
    }

    #[test]
    fn test_normal_flat_surface() {
        let surface = create_flat_surface();

        let normal = compute_normal(&surface, 0.5, 0.5);

        // Flat plane in xy → normal should be [0, 0, ±1]
        assert_relative_eq!(normal[0], 0.0, epsilon = 1e-3);
        assert_relative_eq!(normal[1], 0.0, epsilon = 1e-3);
        assert_relative_eq!(normal[2].abs(), 1.0, epsilon = 1e-3);
    }

    #[test]
    fn test_curvature_flat_surface() {
        let surface = create_flat_surface();

        let (k1, k2) = compute_curvature(&surface, 0.5, 0.5);

        // For a flat plane, principal curvatures should be ~0.
        assert!(k1.abs() < 1e-2, "k1 = {}, expected ~ 0", k1);
        assert!(k2.abs() < 1e-2, "k2 = {}, expected ~ 0", k2);
    }
}
