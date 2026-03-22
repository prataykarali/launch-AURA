use flutter_rust_bridge::frb;

#[frb(sync)]
pub fn aura_chat(input: String) -> String {
    aura_lnn::chat(&input)
}

#[frb(sync)]
pub fn aura_ping() -> String {
    aura_lnn::ping()
}

#[frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}