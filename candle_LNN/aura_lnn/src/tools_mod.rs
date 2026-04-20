// src/tools/mod.rs
//
// Central tool registry — every tool AURA can call lives here.
// To add a new tool:
//   1. Create src/tools/mytool.rs implementing `impl Tool for MyTool`
//   2. Add `pub mod mytool;` below
//   3. Add `.add_tool(MyTool { ... })` in build_tool_registry()
//   Done. RIG handles schema generation and dispatch automatically.

pub mod datetime;
pub mod memory_tools;

use rig::tool::ToolSet;
use crate::tools::datetime::DateTimeTool;
use crate::tools::memory_tools::{MemoryReadTool, MemoryWriteTool, MemoryForgetTool};
use crate::memory::MemoryStore;

pub fn build_tool_registry(mem: MemoryStore) -> ToolSet {
    let mut tools = ToolSet::default();

    // Time tool — fast path, no memory needed
    tools.add_tool(DateTimeTool {});

    // Memory tools — AURA reads/writes her own permanent memory
    // These are the most important tools: they let her remember the user
    // across sessions, across reboots, across years.
    tools.add_tool(MemoryReadTool   { store: mem.clone() });
    tools.add_tool(MemoryWriteTool  { store: mem.clone() });
    tools.add_tool(MemoryForgetTool { store: mem.clone() });

    eprintln!("AURA_TOOLS: registered datetime, memory_read, memory_write, memory_forget");
    tools
}
