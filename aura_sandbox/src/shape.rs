// #[derive(Debug)]
// enum Shape{
//     Circle(f64),
//     Rectangle(f64,f64),
// }
// const PI:f64=3.14;
// impl Shape{
//     fn new_circ(rad:f64)->Self{
//         Self::Circle(rad)

//     }
//     fn new_rec(l:f64,b:f64)->Self{
//         Self::Rectangle(l,b)
//     }
//     fn area(&self){
//         match *self{
//             Self::Circle(rad) => println!("Area of Circle:{}",PI*rad*rad),
//             Self::Rectangle(l,b ) => println!("Area of Rectangle:{}",l*b),

//         }
//     }

// }

// fn main(){
//     let c=Shape::new_circ(5.0);
//     let r=Shape::new_rec(4.0, 7.9);
//     c.area();
//     r.area();
// }


// fn main(){
//     let user_1=10;
//     let user_2=20;
//     match get_mob(user_2){
//         Some(data)=>println!("{data}"),
//         None => print!("User is invalid"),
//     }
// }
// fn get_mob(id:i32)->Option<usize>{
//     let m=290384;
//     if id==10{
//         return Some(m);
//     }
//     else{
//         return None;
//     }
// }

// use std::fmt::Display;
// fn print<T:Display>(data:T){
//     println!("Data:{data}");
// }
// fn main(){
//     let a=String::from("Hello");
//     let b=10;
//     let c=true;
//     print(a);
//     print(b);
//     print(c);
// }

// struct Circle{
//     rad:f64,
// }
// trait Shape{
//     fn area(&self)->f64;
// }
// impl Shape for Circle{
//     fn area(&self)->f64 {
//         3.14*self.rad*self.rad
//     }
// }
// fn main(){
//     let c=Circle{rad:5.0};
//     println!("{:?}",c.area());
// }

fn main(){
    let r:&i32;
    let x=20;
    let y=10;
    r=larger(&x,&y);
    println!("{r}");
}
fn larger<'a>(m:&'a i32, n:&'a i32)->&'a i32{
    if m>n { m } else { n }
}