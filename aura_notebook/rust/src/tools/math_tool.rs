use rig_derive::rig_tool;

#[rig_tool(
    description = "Perform basic arithmetic on two numbers. operation must be one of: +, -, *, /",
    required(x, y, operation)
)]
pub fn calculator(x: f64, y: f64, operation: String) -> Result<f64, rig::tool::ToolError> {
    eprintln!("  [TOOL CALL] calculator({x}, {y}, \"{operation}\")");
    match operation.as_str() {
        "+" => Ok(x + y),
        "-" => Ok(x - y),
        "*" => Ok(x * y),
        "/" => {
            if y == 0.0 {
                Err(rig::tool::ToolError::ToolCallError("Division by zero".into()))
            } else {
                Ok(x / y)
            }
        }
        _ => Err(rig::tool::ToolError::ToolCallError(
            format!("Unknown operation '{operation}'. Use +, -, *, /").into()
        )),
    }
}