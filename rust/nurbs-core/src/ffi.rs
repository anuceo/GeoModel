//! C-compatible FFI for Julia interop

use super::surface::NURBSSurface;
use super::derivatives::{compute_normal, compute_curvature};
use libc::{c_double, c_int};
use ndarray::{Array2, Array3};
use std::slice;

/// Opaque handle to NURBSSurface (for Julia)
pub struct NURBSSurfaceHandle {
    surface: Box<NURBSSurface>,
}

/// Create NURBS surface from raw pointers
///
/// # Safety
/// Caller must ensure all pointers are valid and arrays have correct sizes
#[no_mangle]
pub unsafe extern "C" fn nurbs_create(
    degree_u: c_int,
    degree_v: c_int,
    u_res: c_int,
    v_res: c_int,
    control_points: *const c_double, // Flat array [u_res * v_res * 3]
    weights: *const c_double,        // Flat array [u_res * v_res]
    knots_u: *const c_double,
    knots_v: *const c_double,
    knots_u_len: c_int,
    knots_v_len: c_int,
) -> *mut NURBSSurfaceHandle {
    let u_res = u_res as usize;
    let v_res = v_res as usize;

    // Convert raw pointers to slices
    let control_points_slice = slice::from_raw_parts(control_points, u_res * v_res * 3);
    let weights_slice = slice::from_raw_parts(weights, u_res * v_res);
    let knots_u_slice = slice::from_raw_parts(knots_u, knots_u_len as usize);
    let knots_v_slice = slice::from_raw_parts(knots_v, knots_v_len as usize);

    // Build arrays
    let control_points_array = match Array3::from_shape_vec(
        (u_res, v_res, 3),
        control_points_slice.to_vec(),
    ) {
        Ok(arr) => arr,
        Err(_) => {
            eprintln!("Error: Invalid control points shape");
            return std::ptr::null_mut();
        }
    };

    let weights_array = match Array2::from_shape_vec((u_res, v_res), weights_slice.to_vec()) {
        Ok(arr) => arr,
        Err(_) => {
            eprintln!("Error: Invalid weights shape");
            return std::ptr::null_mut();
        }
    };

    let surface = Box::new(NURBSSurface::new(
        degree_u as usize,
        degree_v as usize,
        control_points_array,
        weights_array,
        knots_u_slice.to_vec(),
        knots_v_slice.to_vec(),
    ));

    Box::into_raw(Box::new(NURBSSurfaceHandle { surface }))
}

/// Evaluate NURBS surface at single point
///
/// # Safety
/// Caller must ensure handle and output are valid
#[no_mangle]
pub unsafe extern "C" fn nurbs_evaluate(
    handle: *mut NURBSSurfaceHandle,
    u: c_double,
    v: c_double,
    output: *mut c_double, // [x, y, z]
) {
    if handle.is_null() || output.is_null() {
        return;
    }

    let handle = &*handle;
    let point = handle.surface.evaluate(u, v);

    let output_slice = slice::from_raw_parts_mut(output, 3);
    output_slice.copy_from_slice(&point);
}

/// Batch evaluation
///
/// # Safety
/// Caller must ensure all pointers are valid and arrays have correct sizes
#[no_mangle]
pub unsafe extern "C" fn nurbs_evaluate_batch(
    handle: *mut NURBSSurfaceHandle,
    uv_pairs: *const c_double, // Flat array [n * 2]
    n: c_int,
    output: *mut c_double, // Flat array [n * 3]
) {
    if handle.is_null() || uv_pairs.is_null() || output.is_null() {
        return;
    }

    let handle = &*handle;
    let uv_slice = slice::from_raw_parts(uv_pairs, (n * 2) as usize);
    let output_slice = slice::from_raw_parts_mut(output, (n * 3) as usize);

    let uv_pairs: Vec<[f64; 2]> = uv_slice
        .chunks_exact(2)
        .map(|chunk| [chunk[0], chunk[1]])
        .collect();

    let points = handle.surface.evaluate_batch(&uv_pairs);

    for (i, point) in points.iter().enumerate() {
        output_slice[i * 3..(i + 1) * 3].copy_from_slice(point);
    }
}

/// Evaluate surface on uniform grid
///
/// # Safety
/// Caller must ensure handle and output are valid and output has size [u_samples * v_samples * 3]
#[no_mangle]
pub unsafe extern "C" fn nurbs_evaluate_grid(
    handle: *mut NURBSSurfaceHandle,
    u_samples: c_int,
    v_samples: c_int,
    output: *mut c_double, // Flat array [u_samples * v_samples * 3]
) {
    if handle.is_null() || output.is_null() {
        return;
    }

    let handle = &*handle;
    let grid = handle.surface.evaluate_grid(u_samples as usize, v_samples as usize);

    let output_slice = slice::from_raw_parts_mut(
        output,
        (u_samples * v_samples * 3) as usize,
    );

    // Copy grid data
    for (idx, &val) in grid.iter().enumerate() {
        output_slice[idx] = val;
    }
}

/// Compute surface normal at a point
///
/// # Safety
/// Caller must ensure handle and output are valid
#[no_mangle]
pub unsafe extern "C" fn nurbs_normal(
    handle: *mut NURBSSurfaceHandle,
    u: c_double,
    v: c_double,
    output: *mut c_double, // [nx, ny, nz]
) {
    if handle.is_null() || output.is_null() {
        return;
    }

    let handle = &*handle;
    let normal = compute_normal(&handle.surface, u, v);

    let output_slice = slice::from_raw_parts_mut(output, 3);
    output_slice.copy_from_slice(&normal);
}

/// Compute principal curvatures at a point
///
/// # Safety
/// Caller must ensure handle and output are valid
#[no_mangle]
pub unsafe extern "C" fn nurbs_curvature(
    handle: *mut NURBSSurfaceHandle,
    u: c_double,
    v: c_double,
    output: *mut c_double, // [k1, k2]
) {
    if handle.is_null() || output.is_null() {
        return;
    }

    let handle = &*handle;
    let (k1, k2) = compute_curvature(&handle.surface, u, v);

    let output_slice = slice::from_raw_parts_mut(output, 2);
    output_slice[0] = k1;
    output_slice[1] = k2;
}

/// Get surface dimensions
///
/// # Safety
/// Caller must ensure handle and output are valid
#[no_mangle]
pub unsafe extern "C" fn nurbs_dimensions(
    handle: *mut NURBSSurfaceHandle,
    u_res: *mut c_int,
    v_res: *mut c_int,
) {
    if handle.is_null() || u_res.is_null() || v_res.is_null() {
        return;
    }

    let handle = &*handle;
    let (u, v) = handle.surface.dimensions();

    *u_res = u as c_int;
    *v_res = v as c_int;
}

/// Free NURBS surface
///
/// # Safety
/// Caller must ensure handle is valid and not used after this call
#[no_mangle]
pub unsafe extern "C" fn nurbs_free(handle: *mut NURBSSurfaceHandle) {
    if !handle.is_null() {
        let _ = Box::from_raw(handle);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ffi_create_and_free() {
        let degree = 1;
        let u_res = 2;
        let v_res = 2;

        let control_points = vec![
            0.0, 0.0, 0.0, // (0, 0)
            0.0, 1.0, 0.0, // (0, 1)
            1.0, 0.0, 0.0, // (1, 0)
            1.0, 1.0, 0.0, // (1, 1)
        ];

        let weights = vec![1.0, 1.0, 1.0, 1.0];
        let knots = vec![0.0, 0.0, 1.0, 1.0];

        unsafe {
            let handle = nurbs_create(
                degree,
                degree,
                u_res,
                v_res,
                control_points.as_ptr(),
                weights.as_ptr(),
                knots.as_ptr(),
                knots.as_ptr(),
                knots.len() as c_int,
                knots.len() as c_int,
            );

            assert!(!handle.is_null());

            let mut output = [0.0; 3];
            nurbs_evaluate(handle, 0.5, 0.5, output.as_mut_ptr());

            assert!((output[0] - 0.5).abs() < 1e-6);
            assert!((output[1] - 0.5).abs() < 1e-6);
            assert!((output[2] - 0.0).abs() < 1e-6);

            nurbs_free(handle);
        }
    }
}
