// fn main(){
//     let mut a=String::from("Hi");
//     app(&mut a);
//     print!("{a}");

// }
// fn app(a: &mut String){
//     {
//     let w1=&mut *a;
//     w1.push_str(" AURA");
//     }
//     let w2=&mut *a;
//     w2.push_str(" Here"); 
// }

// fn main(){
//     let mut a:[&str;3]=["hi","hello","bye"];
//     write(&mut a);
//     print!("{}",a[0]);
// }
// fn write(a:&mut [&str;3]){
//     let b=& *a[0];
    
// }  

use clap::Parser;
use maud::{DOCTYPE, Markup, html};
use pulldown_cmark::{Options, Parser as MarkdownParser, html};
use std::{fs, path::PathBuf};
#[derive(Parser,Debug)]
struct Args{
    //Input markdown file path
    #[arg(long, short)]
    input:String,
    //Output html file path
    #[arg(long, short)]
    output: Option<PathBuf>,
}

fn render_html(content:&str)->Markup{
    html!{
        (DOCTYPE)
        html{
            head{
                meta charset="utf-8";
                title {"Markdown to HTML"}
            }
            body{
                (maud::PreEscaped(content.to_string()))
            }
        }
    }
}
fn main(){
    let arg:Args=Args::parse();
    let mark=fs::read_to_string(&arg.input).expect("Failed to read");

    let mut op=Options::empty();
    op.insert(Options::ENABLE_STRIKETHROUGH);

    let parser=MarkdownParser::new_ext(&mark, op);

    let mut out=String::new();
    html::push_html(&mut out,parser);

    let html_out=render_html(&out).into_string();
    match &arg.output{
        Some(path)=> fs::write(path, html_out).expect("Failed to save"),
        None=>println!("path not provided"),
    }
}