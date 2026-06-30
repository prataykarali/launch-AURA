use serde::{Deserialize, Serialize};

use crate::performance_profile::PerformanceProfile;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum DeviceBackend {
    Cpu,
    Cuda,
    Metal,
    Vulkan,
    Npu,
}

impl DeviceBackend {
    pub fn available() -> Vec<Self> {
        let mut v = vec![Self::Cpu];
        #[cfg(feature = "cuda")]
        v.push(Self::Cuda);
        #[cfg(target_os = "macos")]
        v.push(Self::Metal);
        #[cfg(all(target_os = "linux", not(target_os = "android")))]
        v.push(Self::Vulkan);
        #[cfg(target_os = "android")]
        {
            v.push(Self::Vulkan);
            v.push(Self::Npu);
        }
        v
    }

    pub fn default_for_platform() -> Self {
        #[cfg(target_os = "android")]
        {
            return Self::Cpu;
        }
        #[cfg(target_os = "macos")]
        {
            return Self::Metal;
        }
        #[cfg(target_os = "linux")]
        {
            Self::Cpu
        }
        #[cfg(target_os = "windows")]
        {
            return Self::Cpu;
        }
        #[cfg(target_os = "ios")]
        {
            return Self::Metal;
        }
        #[cfg(not(any(
            target_os = "android",
            target_os = "macos",
            target_os = "linux",
            target_os = "windows",
            target_os = "ios"
        )))]
        Self::Cpu
    }

    pub fn n_threads_for_platform() -> i32 {
        PerformanceProfile::detect().llama_threads
    }
}
