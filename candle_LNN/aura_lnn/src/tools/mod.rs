pub mod datetime;

use rig::tool::ToolSet;
use crate::tools::datetime::DateTimeTool;

pub fn build_tool_registry() -> ToolSet {
    let mut tools = ToolSet::default();
    tools.add_tool(DateTimeTool {});
    // future tools go here:
    // tools.add_tool(KnapsackTool);
    // tools.add_tool(WeatherTool);
    println!("🔧 Tools loaded: 1");
    tools
}