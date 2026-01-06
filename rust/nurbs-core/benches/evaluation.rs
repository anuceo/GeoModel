use criterion::{black_box, criterion_group, criterion_main, Criterion};
use nurbs_core::{CoxDeBoor, NURBSSurface};
use ndarray::{Array2, Array3};

fn benchmark_basis_evaluation(c: &mut Criterion) {
    let knots = vec![0.0, 0.0, 0.0, 0.0, 0.5, 1.0, 1.0, 1.0, 1.0];
    let degree = 3;
    let mut output = vec![0.0; 5];

    c.bench_function("cox_de_boor_basis", |b| {
        b.iter(|| {
            CoxDeBoor::evaluate_all(black_box(0.5), &knots, degree, &mut output);
        })
    });
}

fn benchmark_surface_evaluation(c: &mut Criterion) {
    // Create simple test surface
    let degree = 3;
    let u_res = 5;
    let v_res = 5;

    let mut control_points = Array3::zeros((u_res, v_res, 3));
    for i in 0..u_res {
        for j in 0..v_res {
            control_points[[i, j, 0]] = i as f64 / 4.0;
            control_points[[i, j, 1]] = j as f64 / 4.0;
            control_points[[i, j, 2]] = 0.0;
        }
    }

    let weights = Array2::ones((u_res, v_res));
    let knots = vec![0.0, 0.0, 0.0, 0.0, 0.5, 1.0, 1.0, 1.0, 1.0];

    let surface = NURBSSurface::new(
        degree,
        degree,
        control_points,
        weights,
        knots.clone(),
        knots,
    );

    c.bench_function("surface_single_point", |b| {
        b.iter(|| {
            surface.evaluate(black_box(0.5), black_box(0.5));
        })
    });
}

fn benchmark_batch_evaluation(c: &mut Criterion) {
    let degree = 3;
    let u_res = 5;
    let v_res = 5;

    let mut control_points = Array3::zeros((u_res, v_res, 3));
    for i in 0..u_res {
        for j in 0..v_res {
            control_points[[i, j, 0]] = i as f64 / 4.0;
            control_points[[i, j, 1]] = j as f64 / 4.0;
            control_points[[i, j, 2]] = 0.0;
        }
    }

    let weights = Array2::ones((u_res, v_res));
    let knots = vec![0.0, 0.0, 0.0, 0.0, 0.5, 1.0, 1.0, 1.0, 1.0];

    let surface = NURBSSurface::new(
        degree,
        degree,
        control_points,
        weights,
        knots.clone(),
        knots,
    );

    let uv_pairs: Vec<[f64; 2]> = (0..1000)
        .map(|i| {
            let t = i as f64 / 999.0;
            [t, t]
        })
        .collect();

    c.bench_function("surface_batch_1000", |b| {
        b.iter(|| {
            surface.evaluate_batch(black_box(&uv_pairs));
        })
    });
}

criterion_group!(
    benches,
    benchmark_basis_evaluation,
    benchmark_surface_evaluation,
    benchmark_batch_evaluation
);
criterion_main!(benches);
