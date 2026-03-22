use std::io;
const PLAYER_X:char ='X';
const PLAYER_O:char ='O';
const BOARD:usize=3;
type Board= [[char;BOARD];BOARD];//2d Array create a type of 2d array named as Board

fn initial()->Board{
    return [[' ';BOARD];BOARD];
}
fn print_board(board:&Board){
    for row in board{
        for cell in row{
            print!("{} ",cell);
        }
        println!();
    }
}
fn get_move(current_player:char,board:&Board)->(usize,usize){
    loop{
    println!("Player {current_player} enter your move in (row,col) format 😊");
    let mut input =String::new();
    io::stdin()
       .read_line(&mut input)
       .expect("Invalid input");
    println!("input={}",input);

    let coordinates:Vec<usize>=input 
        .split_whitespace()
        .flat_map(str::parse::<usize>)
        .collect();
    if coordinates.len()==2{
        let (row,col)=(coordinates[0],coordinates[1]);
        if row<BOARD && col<BOARD && board[row][col]==' '{
        return (row,col);
    }
    }
    println!("Invalid input");
    }
}
fn draw(board:&Board)->bool{
    for row in board{
        for cell in row{
            if *cell==' '{
            return false;
        }
    }
    }
    return true;
}
fn check_win(current_player:char,board:&Board)->bool{
    for row in 0..BOARD{
        if board[row][0]==current_player && board[row][1]==current_player && board[row][2]==current_player{
            return true;
        }
    }

    for row in 0..BOARD{
        if board[0][row]==current_player && board[1][row]==current_player && board[2][row]==current_player{
            return true;
        }
    }

    if board[0][0]==current_player && board[1][1]==current_player && board[2][2]==current_player{
        return true;
    }

    else if  board[0][2]==current_player && board[1][1]==current_player && board[2][0]==current_player{
        return true;
    }
    else{
        return false;
    }
}
fn play_game(){
    let mut board=initial();
    let mut current_player=PLAYER_X;

    loop{
        println!("current board:");
        print_board(&mut board);
        let (row,col)=get_move(current_player,&board);
        board[row][col]=current_player;
        if check_win(current_player,&board){
            println!("Winner: {}",current_player);
            break
        }
        if draw(&board){
            println!("Draw game");
            break;
        }
    current_player = if current_player==PLAYER_X{
        PLAYER_O
    } else{
        PLAYER_X
    }
    }
}
fn main(){
    println!("Welcome to Tic Tac Toe");
    play_game();
}