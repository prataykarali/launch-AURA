fn main(){
    let mut a=10;
    {
        let b=&a;
        println!("{}",b);
    }
    a=a+4;
    let c=&a;
    println!("{}",a==*c);
    print!("{}",c);
}
