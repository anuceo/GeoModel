/// Cox-de Boor recursive basis function evaluation
pub struct CoxDeBoor;

impl CoxDeBoor {
    /// Evaluate all non-zero basis functions at parameter t
    pub fn evaluate_all(t: f64, knots: &[f64], degree: usize, output: &mut [f64]) {
        let n = knots.len() - degree - 1;
        assert_eq!(output.len(), n);

        // Initialize to zero
        for val in output.iter_mut() {
            *val = 0.0;
        }

        // Find knot span
        let span = Self::find_span(t, degree, knots);

        // Evaluate non-zero basis functions
        let mut basis = vec![0.0; degree + 1];
        Self::basis_funs(span, t, degree, knots, &mut basis);

        // Copy to output (only non-zero entries)
        for i in 0..=degree {
            let idx = span - degree + i;
            if idx < n {
                output[idx] = basis[i];
            }
        }
    }

    /// Find knot span containing parameter t
    fn find_span(t: f64, degree: usize, knots: &[f64]) -> usize {
        let n = knots.len() - degree - 1;

        // Special case: t at upper bound
        if t >= knots[n] {
            return n - 1;
        }

        // Special case: t at lower bound
        if t <= knots[degree] {
            return degree;
        }

        // Binary search
        let mut low = degree;
        let mut high = n;

        while high - low > 1 {
            let mid = (low + high) / 2;
            if t < knots[mid] {
                high = mid;
            } else {
                low = mid;
            }
        }

        low
    }

    /// Compute non-zero basis functions using Cox-de Boor recursion
    fn basis_funs(span: usize, t: f64, degree: usize, knots: &[f64], output: &mut [f64]) {
        output[0] = 1.0;

        let mut left = vec![0.0; degree + 1];
        let mut right = vec![0.0; degree + 1];

        for j in 1..=degree {
            left[j] = t - knots[span + 1 - j];
            right[j] = knots[span + j] - t;

            let mut saved = 0.0;

            for r in 0..j {
                let temp = output[r] / (right[r + 1] + left[j - r]);
                output[r] = saved + right[r + 1] * temp;
                saved = left[j - r] * temp;
            }

            output[j] = saved;
        }
    }

    /// Compute derivatives of basis functions (for tangent/normal computation)
    pub fn evaluate_derivatives(
        t: f64,
        knots: &[f64],
        degree: usize,
        deriv_order: usize,
        output: &mut [Vec<f64>],
    ) {
        let span = Self::find_span(t, degree, knots);

        // Initialize output
        for row in output.iter_mut() {
            row.resize(degree + 1, 0.0);
        }

        // Basis functions and derivatives (de Boor algorithm extended)
        let mut ndu = vec![vec![0.0; degree + 1]; degree + 1];
        ndu[0][0] = 1.0;

        let mut left = vec![0.0; degree + 1];
        let mut right = vec![0.0; degree + 1];

        for j in 1..=degree {
            left[j] = t - knots[span + 1 - j];
            right[j] = knots[span + j] - t;

            let mut saved = 0.0;

            for r in 0..j {
                ndu[j][r] = right[r + 1] + left[j - r];
                let temp = ndu[r][j - 1] / ndu[j][r];

                ndu[r][j] = saved + right[r + 1] * temp;
                saved = left[j - r] * temp;
            }

            ndu[j][j] = saved;
        }

        // Load basis functions
        for j in 0..=degree {
            output[0][j] = ndu[j][degree];
        }

        // Compute derivatives (if requested)
        for r in 0..=degree {
            let mut s1 = 0;
            let mut s2 = 1;
            let mut a = vec![vec![0.0; degree + 1]; 2];

            a[0][0] = 1.0;

            for k in 1..=deriv_order.min(degree) {
                let mut d = 0.0;
                let rk = r as isize - k as isize;
                let pk = degree - k;

                if r >= k {
                    a[s2][0] = a[s1][0] / ndu[pk + 1][rk as usize];
                    d = a[s2][0] * ndu[rk as usize][pk];
                }

                let j1 = if rk >= -1 { 1 } else { (-rk) as usize };
                let j2 = if r as isize - 1 <= pk as isize {
                    k
                } else {
                    degree - r + 1
                };

                for j in j1..j2 {
                    a[s2][j] = (a[s1][j] - a[s1][j - 1]) / ndu[pk + 1][rk as usize + j];
                    d += a[s2][j] * ndu[rk as usize + j][pk];
                }

                if r <= pk {
                    a[s2][k] = -a[s1][k - 1] / ndu[pk + 1][r];
                    d += a[s2][k] * ndu[r][pk];
                }

                output[k][r] = d;

                std::mem::swap(&mut s1, &mut s2);
            }
        }

        // Multiply by factorials for higher derivatives
        let mut r_factorial = degree as f64;
        for k in 1..=deriv_order.min(degree) {
            for j in 0..=degree {
                output[k][j] *= r_factorial;
            }
            r_factorial *= (degree - k) as f64;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use approx::assert_relative_eq;

    #[test]
    fn test_find_span() {
        let knots = vec![0.0, 0.0, 0.0, 0.0, 0.5, 1.0, 1.0, 1.0, 1.0];
        let degree = 3;

        assert_eq!(CoxDeBoor::find_span(0.0, degree, &knots), 3);
        assert_eq!(CoxDeBoor::find_span(0.25, degree, &knots), 3);
        assert_eq!(CoxDeBoor::find_span(0.5, degree, &knots), 4);
        assert_eq!(CoxDeBoor::find_span(0.75, degree, &knots), 4);
        assert_eq!(CoxDeBoor::find_span(1.0, degree, &knots), 4);
    }

    #[test]
    fn test_basis_functions() {
        let knots = vec![0.0, 0.0, 0.0, 1.0, 1.0, 1.0];
        let degree = 2;
        let span = 2;
        let t = 0.5;

        let mut basis = vec![0.0; degree + 1];
        CoxDeBoor::basis_funs(span, t, degree, &knots, &mut basis);

        // For quadratic Bernstein: B0(0.5) = 0.25, B1(0.5) = 0.5, B2(0.5) = 0.25
        assert_relative_eq!(basis[0], 0.25, epsilon = 1e-10);
        assert_relative_eq!(basis[1], 0.5, epsilon = 1e-10);
        assert_relative_eq!(basis[2], 0.25, epsilon = 1e-10);
    }
}
