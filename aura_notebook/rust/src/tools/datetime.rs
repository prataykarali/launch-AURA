use rig::completion::ToolDefinition;
use rig::tool::Tool;
use serde::{Deserialize,Serialize};
use serde_json::json;
use chrono::Local;

#[derive(Deserialize)]
pub struct DateTimeArgs{
    pub format: Option<String>
}

#[derive(Serialize)]
pub struct DateTimeOutput{
    pub datetime:String,
}

#[derive(Debug, thiserror::Error)]
#[error("DateTime error")]
pub struct DateTimeError;
pub struct DateTimeTool;

impl Tool for DateTimeTool{
    const NAME:&'static str="get_time";
    type Error=DateTimeError;
    type Args=DateTimeArgs;
    type Output = DateTimeOutput;
    async fn definition(&self, _prompt:String)->ToolDefinition{
        ToolDefinition{
            name:"get_time".to_string(),
            description: "Returns current date and time".to_string(),
            parameters: json!({
                "type":"object",
                "properties": {
                    "format": {
                        "type": "string",
                        "description": "Optional format string"
                    }
                }
            })
        }
    }
    async fn call(&self,_args:Self::Args)->Result<Self::Output, Self::Error>{
        let now=Local::now();
        let formatted = now.format("%I:%M %p, %B %d %Y").to_string();
        Ok(DateTimeOutput {datetime: formatted})
    }
}

