//! 3x3 matrix operations

use serde::{Serialize, Deserialize};
use super::Vec3;

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct Mat3 {
    pub data: [[f64; 3]; 3],
}

impl Mat3 {
    pub fn new(data: [[f64; 3]; 3]) -> Self {
        Self { data }
    }

    pub fn identity() -> Self {
        Self::new([
            [1.0, 0.0, 0.0],
            [0.0, 1.0, 0.0],
            [0.0, 0.0, 1.0],
        ])
    }

    pub fn zero() -> Self {
        Self::new([[0.0; 3]; 3])
    }

    pub fn mul_vec(&self, v: &Vec3) -> Vec3 {
        Vec3::new(
            self.data[0][0] * v.x + self.data[0][1] * v.y + self.data[0][2] * v.z,
            self.data[1][0] * v.x + self.data[1][1] * v.y + self.data[1][2] * v.z,
            self.data[2][0] * v.x + self.data[2][1] * v.y + self.data[2][2] * v.z,
        )
    }
}
