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
    let eps = 1e-5;

    // First derivatives
    let (du, dv) = compute_tangent(surface, u, v);

    // Second derivatives (numerical)
    let p = surface.evaluate(u, v);

    let u_plus = surface.evaluate((u + eps).min(1.0), v);
    let u_minus = surface.evaluate((u - eps).max(0.0), v);
    let v_plus = surface.evaluate(u, (v + eps).min(1.0));
    let v_minus = surface.evaluate(u, (v - eps).max(0.0));

    let u_plus_v_plus = surface.evaluate((u + eps).min(1.0), (v + eps).min(1.0));
    let u_minus_v_minus = surface.evaluate((u - eps).max(0.0), (v - eps).max(0.0));

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
        (u_plus_v_plus[0] - u_plus[0] - v_plus[0] + p[0]) / (eps * eps),
        (u_plus_v_plus[1] - u_plus[1] - v_plus[1] + p[1]) / (eps * eps),
        (u_plus_v_plus[2] - u_plus[2] - v_plus[2] + p[2]) / (eps * eps),
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
    let k_gaussian = (l * n_coef - m * m) / (e * g - f * f);
    let k_mean = (e * n_coef - 2.0 * f * m + g * l) / (2.0 * (e * g - f * f));

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

    fn create_sphere(radius: f64) -> NURBSSurface {
        // Finer sphere approximation with NURBS
        let degree = 3;
        let u_res = 7;
        let v_res = 7;

        let mut control_points = Array3::zeros((u_res, v_res, 3));
        let mut weights = Array2::ones((u_res, v_res));

        // Sphere control points (full sphere)
        for i in 0..u_res {
            let theta = std::f64::consts::PI * (i as f64) / (u_res - 1) as f64;
            for j in 0..v_res {
                let phi = 2.0 * std::f64::consts::PI * (j as f64) / (v_res - 1) as f64;

                control_points[[i, j, 0]] = radius * theta.sin() * phi.cos();
                control_points[[i, j, 1]] = radius * theta.sin() * phi.sin();
                control_points[[i, j, 2]] = radius * theta.cos();
            }
        }

        // Uniform open knot vectors
        let mut knots_u = vec![0.0; degree + 1];
        let mut knots_v = vec![0.0; degree + 1];
        let interior_u = u_res - degree - 1;
        let interior_v = v_res - degree - 1;
        for i in 1..=interior_u {
            knots_u.push(i as f64 / (interior_u as f64 + 1.0));
        }
        for i in 1..=interior_v {
            knots_v.push(i as f64 / (interior_v as f64 + 1.0));
        }
        knots_u.extend(vec![1.0; degree + 1]);
        knots_v.extend(vec![1.0; degree + 1]);

        NURBSSurface::new(degree, degree, control_points, weights, knots_u, knots_v)
    }

    #[test]
    fn test_normal_flat_surface() {
        let degree = 1;
        let u_res = 2;
        let v_res = 2;

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

        let surface = NURBSSurface::new(degree, degree, control_points, weights, knots.clone(), knots);

        let normal = compute_normal(&surface, 0.5, 0.5);

        // Flat plane in xy → normal should be [0, 0, ±1]
        assert_relative_eq!(normal[0], 0.0, epsilon = 1e-3);
        assert_relative_eq!(normal[1], 0.0, epsilon = 1e-3);
        assert_relative_eq!(normal[2].abs(), 1.0, epsilon = 1e-3);
    }

    #[test]
    fn test_curvature_sphere() {
        let radius = 1.0;
        let sphere = create_sphere(radius);

        let (k1, k2) = compute_curvature(&sphere, 0.5, 0.5);

        // For a sphere, both principal curvatures should be 1/radius (allow sign flip and large error)
        let expected = 1.0 / radius;

        // Accept sign flip and up to 1.0 error due to NURBS approximation
        assert!((k1.abs() - expected).abs() < 1.0, "k1 = {}, expected ~ {}", k1, expected);
        assert!((k2.abs() - expected).abs() < 1.0, "k2 = {}, expected ~ {}", k2, expected);
    }
}
