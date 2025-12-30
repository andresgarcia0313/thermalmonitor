//! System interface for reading thermal and CPU information from sysfs
//!
//! This module reads directly from Linux sysfs to minimize dependencies.
//! All temperatures are in Celsius, frequencies in MHz.

use std::fs;
use std::io::{self, ErrorKind};
use std::process::Command;

/// Thermal attenuation factor for keyboard temperature estimation
/// Based on physical model: T_kbd = T_amb + (T_cpu - T_amb) * ATTENUATION
const THERMAL_ATTENUATION: f32 = 0.45;

/// Default ambient temperature when not measurable
const DEFAULT_AMBIENT: f32 = 28.0;

/// CPU mode enumeration
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum Mode {
    Performance,
    Comfort,
    Balanced,
    Quiet,
    #[default]
    Auto,
    Unknown,
}

impl Mode {
    pub fn label(&self) -> &'static str {
        match self {
            Mode::Performance => "PERFORMANCE",
            Mode::Comfort => "COMFORT",
            Mode::Balanced => "BALANCED",
            Mode::Quiet => "QUIET",
            Mode::Auto => "AUTO",
            Mode::Unknown => "UNKNOWN",
        }
    }

    pub fn command(&self) -> &'static str {
        match self {
            Mode::Performance => "performance",
            Mode::Comfort => "comfort",
            Mode::Balanced => "balanced",
            Mode::Quiet => "quiet",
            Mode::Auto => "auto",
            Mode::Unknown => "auto",
        }
    }

    pub fn description(&self) -> &'static str {
        match self {
            Mode::Performance => "100% - Video calls",
            Mode::Comfort => "60% - Cool keyboard",
            Mode::Balanced => "75% - General use",
            Mode::Quiet => "40% - Silent",
            Mode::Auto => "Automatic",
            Mode::Unknown => "Unknown",
        }
    }

    pub fn all() -> &'static [Mode] {
        &[Mode::Performance, Mode::Comfort, Mode::Balanced, Mode::Quiet, Mode::Auto]
    }
}

/// Thermal zone classification
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ThermalZone {
    Cool,      // < 40°C
    Comfort,   // 40-45°C
    Optimal,   // 45-50°C
    Warm,      // 50-55°C
    Hot,       // 55-65°C
    Critical,  // > 65°C
}

impl ThermalZone {
    pub fn from_cpu_temp(temp: f32) -> Self {
        match temp {
            t if t < 40.0 => ThermalZone::Cool,
            t if t < 45.0 => ThermalZone::Comfort,
            t if t < 50.0 => ThermalZone::Optimal,
            t if t < 55.0 => ThermalZone::Warm,
            t if t < 65.0 => ThermalZone::Hot,
            _ => ThermalZone::Critical,
        }
    }

    pub fn label(&self) -> &'static str {
        match self {
            ThermalZone::Cool => "COOL",
            ThermalZone::Comfort => "COMFORT",
            ThermalZone::Optimal => "OPTIMAL",
            ThermalZone::Warm => "WARM",
            ThermalZone::Hot => "HOT",
            ThermalZone::Critical => "CRITICAL",
        }
    }

    /// Returns RGB color tuple
    pub fn color_rgb(&self) -> (u8, u8, u8) {
        match self {
            ThermalZone::Cool => (100, 200, 255),     // Light blue
            ThermalZone::Comfort => (100, 220, 100),  // Green
            ThermalZone::Optimal => (150, 220, 100),  // Light green
            ThermalZone::Warm => (255, 200, 100),     // Yellow
            ThermalZone::Hot => (255, 150, 100),      // Orange
            ThermalZone::Critical => (255, 100, 100), // Red
        }
    }
}

/// Read a single value from a sysfs file
fn read_sysfs_value(path: &str) -> io::Result<String> {
    fs::read_to_string(path).map(|s| s.trim().to_string())
}

/// Read CPU temperature from thermal zones
/// Tries x86_pkg_temp first, then TCPU, then any available
pub fn read_cpu_temp() -> io::Result<f32> {
    // Try known thermal zone paths
    let paths = [
        "/sys/class/thermal/thermal_zone10/temp", // x86_pkg_temp on IdeaPad
        "/sys/class/thermal/thermal_zone8/temp",  // TCPU
        "/sys/class/thermal/thermal_zone0/temp",  // fallback
    ];

    for path in paths {
        if let Ok(content) = read_sysfs_value(path) {
            if let Ok(millicelsius) = content.parse::<i32>() {
                let temp = millicelsius as f32 / 1000.0;
                if temp > 0.0 && temp < 150.0 {
                    return Ok(temp);
                }
            }
        }
    }

    // Scan all thermal zones for x86_pkg_temp or TCPU
    for i in 0..15 {
        let type_path = format!("/sys/class/thermal/thermal_zone{}/type", i);
        let temp_path = format!("/sys/class/thermal/thermal_zone{}/temp", i);

        if let Ok(zone_type) = read_sysfs_value(&type_path) {
            if zone_type == "x86_pkg_temp" || zone_type == "TCPU" {
                if let Ok(content) = read_sysfs_value(&temp_path) {
                    if let Ok(millicelsius) = content.parse::<i32>() {
                        return Ok(millicelsius as f32 / 1000.0);
                    }
                }
            }
        }
    }

    Err(io::Error::new(ErrorKind::NotFound, "No CPU temperature sensor found"))
}

/// Read ambient temperature (from ACPI thermal zone)
pub fn read_ambient_temp() -> f32 {
    // Try acpitz which usually reports chassis/ambient temp
    if let Ok(content) = read_sysfs_value("/sys/class/thermal/thermal_zone0/temp") {
        if let Ok(millicelsius) = content.parse::<i32>() {
            let temp = millicelsius as f32 / 1000.0;
            if temp > 15.0 && temp < 50.0 {
                return temp;
            }
        }
    }
    DEFAULT_AMBIENT
}

/// Calculate estimated keyboard temperature using thermal physics model
/// Formula: T_kbd = T_amb + (T_cpu - T_amb) * attenuation_factor
pub fn calculate_keyboard_temp(cpu_temp: f32, ambient_temp: f32) -> f32 {
    ambient_temp + (cpu_temp - ambient_temp) * THERMAL_ATTENUATION
}

/// Read current performance percentage from intel_pstate
pub fn read_perf_pct() -> io::Result<u8> {
    let content = read_sysfs_value("/sys/devices/system/cpu/intel_pstate/max_perf_pct")?;
    content.parse::<u8>().map_err(|e| io::Error::new(ErrorKind::InvalidData, e))
}

/// Read current CPU frequency in MHz
pub fn read_current_freq() -> io::Result<u32> {
    let content = read_sysfs_value("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq")?;
    let khz: u32 = content.parse().map_err(|e| io::Error::new(ErrorKind::InvalidData, e))?;
    Ok(khz / 1000)
}

/// Read maximum CPU frequency in MHz
pub fn read_max_freq() -> io::Result<u32> {
    let content = read_sysfs_value("/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq")?;
    let khz: u32 = content.parse().map_err(|e| io::Error::new(ErrorKind::InvalidData, e))?;
    Ok(khz / 1000)
}

/// Read current mode from cpu-mode status file
pub fn read_mode() -> Mode {
    if let Ok(content) = read_sysfs_value("/tmp/cpu-mode.current") {
        let lower = content.to_lowercase();
        if lower.contains("performance") {
            Mode::Performance
        } else if lower.contains("comfort") {
            if lower.contains("auto") || lower.contains("-") {
                Mode::Auto // comfort-OPTIMAL, etc.
            } else {
                Mode::Comfort
            }
        } else if lower.contains("balanced") {
            Mode::Balanced
        } else if lower.contains("quiet") {
            Mode::Quiet
        } else if lower.contains("auto") {
            Mode::Auto
        } else {
            Mode::Unknown
        }
    } else {
        Mode::Unknown
    }
}

/// Read platform profile
pub fn read_platform_profile() -> String {
    read_sysfs_value("/sys/firmware/acpi/platform_profile").unwrap_or_else(|_| "unknown".into())
}

/// Change CPU mode using pkexec
pub fn set_mode(mode: Mode) -> io::Result<()> {
    let output = Command::new("pkexec")
        .args(["/usr/local/bin/cpu-mode", mode.command()])
        .output()?;

    if output.status.success() {
        Ok(())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr);
        Err(io::Error::new(ErrorKind::Other, format!("Failed to change mode: {}", stderr)))
    }
}

/// Complete thermal state snapshot
#[derive(Debug, Clone, Default)]
pub struct ThermalState {
    pub cpu_temp: f32,
    pub keyboard_temp: f32,
    pub ambient_temp: f32,
    pub perf_pct: u8,
    pub current_freq_mhz: u32,
    pub max_freq_mhz: u32,
    pub mode: Mode,
    pub platform_profile: String,
}

impl ThermalState {
    /// Read complete thermal state from system
    pub fn read() -> Self {
        let cpu_temp = read_cpu_temp().unwrap_or(50.0);
        let ambient_temp = read_ambient_temp();
        let keyboard_temp = calculate_keyboard_temp(cpu_temp, ambient_temp);

        Self {
            cpu_temp,
            keyboard_temp,
            ambient_temp,
            perf_pct: read_perf_pct().unwrap_or(50),
            current_freq_mhz: read_current_freq().unwrap_or(1000),
            max_freq_mhz: read_max_freq().unwrap_or(4400),
            mode: read_mode(),
            platform_profile: read_platform_profile(),
        }
    }

    /// Get thermal zone classification
    pub fn thermal_zone(&self) -> ThermalZone {
        ThermalZone::from_cpu_temp(self.cpu_temp)
    }

    /// Get current frequency in GHz
    pub fn current_freq_ghz(&self) -> f32 {
        self.current_freq_mhz as f32 / 1000.0
    }

    /// Get max frequency in GHz
    pub fn max_freq_ghz(&self) -> f32 {
        self.max_freq_mhz as f32 / 1000.0
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_thermal_zone_classification() {
        assert_eq!(ThermalZone::from_cpu_temp(35.0), ThermalZone::Cool);
        assert_eq!(ThermalZone::from_cpu_temp(42.0), ThermalZone::Comfort);
        assert_eq!(ThermalZone::from_cpu_temp(47.0), ThermalZone::Optimal);
        assert_eq!(ThermalZone::from_cpu_temp(52.0), ThermalZone::Warm);
        assert_eq!(ThermalZone::from_cpu_temp(60.0), ThermalZone::Hot);
        assert_eq!(ThermalZone::from_cpu_temp(70.0), ThermalZone::Critical);
    }

    #[test]
    fn test_keyboard_temp_calculation() {
        // At 50°C CPU with 28°C ambient: 28 + (50-28)*0.45 = 28 + 9.9 = 37.9
        let kbd = calculate_keyboard_temp(50.0, 28.0);
        assert!((kbd - 37.9).abs() < 0.1);

        // At ambient temp, keyboard should be at ambient
        let kbd = calculate_keyboard_temp(28.0, 28.0);
        assert!((kbd - 28.0).abs() < 0.1);
    }

    #[test]
    fn test_mode_properties() {
        assert_eq!(Mode::Performance.command(), "performance");
        assert_eq!(Mode::Comfort.label(), "COMFORT");
        assert_eq!(Mode::all().len(), 5);
    }

    #[test]
    fn test_thermal_zone_colors() {
        let (r, g, b) = ThermalZone::Cool.color_rgb();
        assert!(b > r); // Blue should be dominant for cool

        let (r, g, b) = ThermalZone::Critical.color_rgb();
        assert!(r > g && r > b); // Red should be dominant for critical
    }
}
