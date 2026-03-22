// fn main(){
//     let a=String::from("Hello");
//     let (b,l)=a_len(a);
//     print!("Length of {b} is {l}");
// }
// fn a_len(a:String)->(String,usize){
//     let lg=a.len();
//     return (a,lg);
// }

// fn main(){
//     fn math(a:i8)->bool{
//         if a%2==0{
//             return true;
//         }
//         else{
//             return false;
//         }
//     }

//     let n=9;
//     match n{
//         x if math(x)=>print!("Even"),
//         y if !math(y)=>print!("Odd"),
//         _=>print!("Invalid"),
//     }
// }
// use std::io;

// fn main(){
//     let mut i=String::new();
//     println!("Enter a string");
//     io::stdin()
//          .read_line(&mut i)
//          .expect("Failed to allocate");
//     println!("User input {i}");
// }

// #[derive(Debug)]
// struct Student{
//     name:String,
//     age:usize,
//     pass:bool,
// }

// fn main(){
//     let a:Student=Student { name: String::from("Pratay"), age: (20), pass: (true) };
//     println!("Student: {:?}",a);
// }

// use std::fs::File;
// fn create_file(file_path:&str)->Result<File,io::Error>{
//     let file=File::create(file_path)?;
//     Ok(file)
// }
// fn main(){
//     match create_file("Hello world"){
//         Ok(_) => println!("Success"),
//         Err(e)=>println!("Error"),
//     }
// }

// fn main(){
//     // let add_one=|x:i32|x+1;
//     // println!("{}",add_one(5));

//     let mut counter=0;
//     let mut increase=||{
//         counter+=1;
//         println!("{counter}");
//     };
//     increase();
//     increase();
//     increase();
// }

// use itertools::Itertools;
// fn main(){
//     let v=vec![1,2,3,4];
//     let dob:Vec<i32>=v.iter().map(|x:&i32|x*2).collect();
//     println!("[{}]", dob.iter().format(", "));
//     let d:Vec<&i32>=v.iter().filter(|x|*x%2==0).collect();

//     match v.iter().copied().reduce(|a,i|a+i){
//         Some(sum)=>println!("{}",sum),
//         None=>println!("None"),
//     }
// }

use itertools::Itertools;
fn main(){
    let n=vec![1,2,3,4,5];
    let i=n.iter();
    let f:Vec<i32>=i.filter(|x|*x%2!=0).copied().collect();
    println!("[{}]",f.iter().format(", "));
    let inc:Vec<i32>=f.iter().map(|x:&i32|x+1).collect();
    match inc.iter().find(|x|**x==6){
        Some(i)=>println!("{}",i),
        None=>println!("None"),
    }
}