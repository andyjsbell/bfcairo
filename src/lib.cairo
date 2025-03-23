use core::array::Array;
use core::dict::Felt252Dict;
use core::array::ArrayTrait;

#[derive(Drop, PartialEq, Debug)]
enum Op {
    RIGHT,
    LEFT,
    INC,
    DEC,
    OUT,
    REPLACE,
    JUMP_IF_ZERO,
    JUMP_UNLESS_ZERO,
    VALUE: u8,
}

impl CharIntoOp of TryInto<u8, Op> {
    fn try_into(self: u8) -> Option<Op> {
        if self == '>' {
            return Option::Some(Op::RIGHT);
        } else if self == '<' {
            return Option::Some(Op::LEFT);
        } else if self == '+' {
            return Option::Some(Op::INC);
        } else if self == '-' {
            return Option::Some(Op::DEC);
        } else if self == '.' {
            return Option::Some(Op::OUT);
        } else if self == ',' {
            return Option::Some(Op::REPLACE);
        } else if self == '[' {
            return Option::Some(Op::JUMP_IF_ZERO);
        } else if self == ']' {
            return Option::Some(Op::JUMP_UNLESS_ZERO);
        } else {
            return Option::Some(Op::VALUE(self));
        }
    }
}

fn bracket_map(program: @Array<Op>) -> Array<(u32, u32)> {
    // Run through program returning a map of the mathing []
    let mut position: u32 = 0;
    let mut left = ArrayTrait::new();
    let mut pairs = ArrayTrait::new();

    loop {
        if position == program.len() {
            break;
        }
        match program.get(position).unwrap().unbox() {
            Op::JUMP_IF_ZERO => { left.append(position); },
            Op::JUMP_UNLESS_ZERO => {
                let mut left_span = left.span();
                let left_position = left_span.pop_back().unwrap();
                left = left_span.into();
                let pair = (*left_position, position);
                pairs.append(pair);
            },
            _ => {},
        }
        position += 1;
    };

    pairs
}

fn run(program: Array<Op>) -> ByteArray {
    let mut program_counter: u32 = 0;
    let mut address_pointer = 0;
    let mut memory: Felt252Dict<u8> = Default::default();
    let mut out: ByteArray = "";

    let mut brackets = bracket_map(@program);

    loop {
        if program_counter == program.len() {
            break;
        }

        let op = program.get(program_counter).unwrap().unbox();

        match op {
            Op::RIGHT => address_pointer += 1,
            Op::LEFT => address_pointer -= 1,
            Op::INC => memory.insert(address_pointer, memory.get(address_pointer) + 1),
            Op::DEC => memory.insert(address_pointer, memory.get(address_pointer) - 1),
            Op::OUT => out.append_byte(memory.get(address_pointer)),
            Op::REPLACE => {
                match program.get(program_counter).unwrap().unbox() {
                    Op::VALUE(input) => memory.insert(address_pointer, *input),
                    _ => panic!("Expected value!"),
                }

                program_counter += 1;
            },
            Op::JUMP_IF_ZERO => {
                if memory.get(address_pointer) == 0 {
                    let (_, end) = brackets.pop_front().unwrap();
                    program_counter = end;
                }
            },
            Op::JUMP_UNLESS_ZERO => {
                if memory.get(address_pointer) != 0 {
                    let (start, _) = brackets.get(0).unwrap().unbox();
                    program_counter = *start;
                }
            },
            Op::VALUE => { panic!("Unexpected value!"); },
        }

        program_counter += 1;
    };

    out
}

fn interpretor(program: Array<u8>) -> Array<Op> {
    let mut new_program = ArrayTrait::new();

    for line in program {
        new_program.append(line.try_into().unwrap());
    };

    new_program
}

fn interpret_code(code: ByteArray) -> Array<Op> {
    let mut interpreted_code = ArrayTrait::new();
    let mut index = 0;
    loop {
        if index == code.len() {
            break;
        }
        let c: Op = code.at(index).unwrap().try_into().unwrap();
        interpreted_code.append(c);
        index += 1;
    };
    interpreted_code
}

#[executable]
fn main() -> Array<felt252> {
    // let code: ByteArray =
    //         "++++++++++[>+>+++>+++++++>++++++++++<<<<-]>>>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>.";
    // let _out = run(interpret_code(code));
    array![42]
}

#[cfg(test)]
mod tests {
    use super::{run, Op, interpret_code};
    use core::array::ArrayTrait;

    #[test]
    fn output() {
        let mut program = ArrayTrait::new();
        program.append(Op::INC);
        program.append(Op::OUT);
        let out = run(program);
        assert(out.at(0).unwrap() == 1, 1);
    }

    #[test]
    fn hello_world() {
        let code: ByteArray =
            "++++++++++[>+>+++>+++++++>++++++++++<<<<-]>>>++.>+.+++++++..+++.>++.<<+++++++++++++++.>.+++.------.--------.>+.>.";
        let out = run(interpret_code(code));
        let expected_output: ByteArray = "Hello\x02World\x03\0";
        assert_eq!(out, expected_output);
    }
}
