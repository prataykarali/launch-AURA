use csv::{Reader, Writer};
use serde::{Serialize, Deserialize};
use std::fs::File;
use std::io::Read;

#[derive(Serialize)]
#[derive(Debug, Deserialize)]
pub struct Task{
    pub task_name:String,
    pub task_description:String,
    pub task_complete:String,
}

pub fn save_tasks(tasks:&Vec<Task>){
    let mut file=File::create("Task.csv").unwrap();
    let mut writer=Writer::from_writer(file);
    for task in tasks{
        writer.serialize(task).unwrap();
    }
}

pub fn load_task()->Vec<Task>{
    let mut tasks:Vec<Task>=vec![];
    let mut file=File::open("task.csv").unwrap_or_else(|_|
    File::create("task.csv").unwrap());
    println!("File:{:?}",file);
    let mut content=String::new();
    match file.read_to_string(&mut content){
        Ok(_)=>{
            println!("Content:{:?}",content);
            let mut reader=Reader::from_reader(content.as_bytes());
            println!("Reader:{:?}",reader);
            for result in reader.deserialize::<Task>(){
                let task:Task=result.unwrap();
                tasks.push(task);
            }
        },
        Err(e) => println!("Parsing error: {:?}", e),
    }
    tasks
}