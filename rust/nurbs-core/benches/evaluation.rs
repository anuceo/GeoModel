use criterion::{black_box, criterion_group, criterion_main, Criterion};
use nurbs_core::CoxDeBoor;

fn bench_basis_evaluate_all(c: &mut Criterion) {
    // A small, representative knot vector for a cubic spline.
    let knots = vec![0.0, 0.0, 0.0, 0.0, 0.5, 1.0, 1.0, 1.0, 1.0];
    let degree = 3;
    let mut basis = vec![0.0; 5];

    c.bench_function("cox_de_boor::evaluate_all", |b| {
        b.iter(|| {
            CoxDeBoor::evaluate_all(black_box(0.5), black_box(&knots), degree, &mut basis);
            black_box(&basis);
        })
    });
}

criterion_group!(benches, bench_basis_evaluate_all);
criterion_main!(benches);

