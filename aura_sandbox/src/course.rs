#[derive(Debug)]
struct Workshop{
    title:String,
    instructor:String,
    duration:String,
}
struct Seminar{
    title:String,
    speaker:String,
    location:String,
}

trait Course{
    fn get_overview(&self)->String;
}
impl Course for Workshop{
    fn get_overview(&self)->String{
        format!(
            "Workshop title:{}, instructor:{}, duration:{}"
            ,self.title, self.instructor,self.duration
        )
    }
}

impl Course for Seminar{
     fn get_overview(&self)->String{
        format!(
            "Seminar title:{}, speaker:{}, location:{}"
            ,self.title, self.speaker,self.location
        )
        }
     }
fn print_overview<T:Course>(data:T){
    println!("{}",data.get_overview());
}
fn main(){
    let i:Workshop=Workshop{title:"AI robot".to_owned(),instructor:"ABC".to_owned(),duration:"3hrs".to_owned()};
    print_overview(i);
let j:Seminar=Seminar{title:"AI robot".to_owned(),speaker:"ABC".to_owned(),location:"Kolkata".to_owned()};
    print_overview(j);
}
