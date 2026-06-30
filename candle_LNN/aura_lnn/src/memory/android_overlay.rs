/// Android overlay configuration for AURA Bar.
///
/// Provides:
/// - Full `OverlayConfig` with width/height/gravity/background ARGB fields.
/// - `validate_translucency()` for asserting config invariants.
/// - `aura_get_overlay_config()` — FFI-queryable JSON export.
///
/// Overlay window configuration hints for the Flutter / Android layer.
#[derive(Debug, Clone)]
pub struct OverlayConfig {
    /// PixelFormat constant name: "PixelFormat.TRANSLUCENT"
    pub pixel_format: &'static str,
    /// Width sizing mode: "WRAP_CONTENT"
    pub width_mode: &'static str,
    /// Exact overlay height in dp.
    pub height_dp: u32,
    /// Gravity flags string: "Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL"
    pub gravity: &'static str,
    /// Background color in ARGB hex (0x00000000 = fully transparent).
    pub background_color: u32,
    /// Whether the overlay is translucent.
    pub translucent: bool,
    /// Whether the overlay is sized tight to the bar widget.
    pub tight_to_widget: bool,
}

impl Default for OverlayConfig {
    /// Production defaults for the AURA Bar floating overlay.
    fn default() -> Self {
        OverlayConfig {
            pixel_format: "PixelFormat.TRANSLUCENT",
            width_mode: "WRAP_CONTENT",
            height_dp: 130,
            gravity: "Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL",
            background_color: 0x0000_0000, // fully transparent ARGB
            translucent: true,
            tight_to_widget: true,
        }
    }
}

impl OverlayConfig {
    /// Verify that the config invariants hold.
    /// Returns `true` if all invariants pass; logs a warning and returns
    /// `false` otherwise.
    pub fn validate_translucency(&self) -> bool {
        let mut ok = true;

        if !self.translucent {
            eprintln!("[AURA_OVERLAY_WARN] translucent must be true to avoid black boundaries");
            ok = false;
        }
        if self.background_color & 0xFF00_0000 != 0 {
            eprintln!(
                "[AURA_OVERLAY_WARN] background_color alpha is non-zero ({:#010x}); \
                 overlay will have a visible background tint",
                self.background_color
            );
            ok = false;
        }
        if self.height_dp > 600 {
            eprintln!(
                "[AURA_OVERLAY_WARN] height_dp={} exceeds 600dp; overlay may extend beyond bar",
                self.height_dp
            );
            ok = false;
        }
        if !self.tight_to_widget {
            eprintln!(
                "[AURA_OVERLAY_WARN] tight_to_widget=false; overlay may bleed beyond AURA Bar bounds"
            );
            ok = false;
        }

        ok
    }

    /// Serialize config as a compact JSON string for FFI export.
    pub fn to_json(&self) -> String {
        format!(
            r#"{{"pixel_format":"{pf}","width_mode":"{wm}","height_dp":{hdp},"gravity":"{grav}","background_color":{bg},"translucent":{tr},"tight_to_widget":{ttw}}}"#,
            pf = self.pixel_format,
            wm = self.width_mode,
            hdp = self.height_dp,
            grav = self.gravity,
            bg = self.background_color,
            tr = self.translucent,
            ttw = self.tight_to_widget,
        )
    }
}

// ── Public helpers ─────────────────────────────────────────────────────────────

pub fn get_overlay_config() -> OverlayConfig {
    OverlayConfig::default()
}

/// FFI-queryable JSON representation of the default overlay config.
pub fn aura_get_overlay_config() -> String {
    let cfg = get_overlay_config();
    let valid = cfg.validate_translucency();
    if !valid {
        eprintln!(
            "[AURA_OVERLAY_WARN] Default overlay config has validation warnings — check above"
        );
    }
    cfg.to_json()
}

#[cfg(test)]
mod tests {
    use super::{aura_get_overlay_config, get_overlay_config};

    #[test]
    fn overlay_defaults() {
        let c = get_overlay_config();
        assert!(c.translucent);
        assert!(c.tight_to_widget);
        assert_eq!(c.background_color, 0);
        assert_eq!(c.height_dp, 130);
    }

    #[test]
    fn validate_passes_defaults() {
        let c = get_overlay_config();
        assert!(c.validate_translucency());
    }

    #[test]
    fn validate_fails_non_transparent() {
        let mut c = get_overlay_config();
        c.background_color = 0xFF00_0000; // opaque black
        assert!(!c.validate_translucency());
    }

    #[test]
    fn to_json_contains_fields() {
        let json = aura_get_overlay_config();
        assert!(json.contains("pixel_format"));
        assert!(json.contains("height_dp"));
        assert!(json.contains("gravity"));
    }
}
