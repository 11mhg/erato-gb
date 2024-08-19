const std = @import("std");
const game_allocator = @import("game_allocator.zig");
const game_errors = @import("game_errors.zig");

pub const InstructionType = enum {
    NONE,
    NOP,
    LD,
    LDI,
    LDD,
    INC,
    DEC,
    RLCA,
    ADD,
    RRCA,
    STOP,
    RLA,
    JR,
    RRA,
    DAA,
    CPL,
    SCF,
    CCF,
    HALT,
    ADC,
    SUB,
    SBC,
    AND,
    XOR,
    OR,
    CP,
    POP,
    JP,
    PUSH,
    RET,
    CB,
    CALL,
    RETI,
    LDH,
    JPHL,
    DI,
    EI,
    RST,
    ERR,
    // CB Instructions
    RLC,
    RRC,
    RL,
    RR,
    SLA,
    SRA,
    SWAP,
    SRL,
    BIT,
    RES,
    SET,
};

pub const AddressMode = enum {
    IMP,
    R,
    N16,
    PTR,
    PTR_R,
    R_R,
    R_N8,
    R_N16,
    R_PTR,
    R_A8,
    N16_R,
    A8_R,
    A16_R,
};

pub const RegisterType = enum { NONE, A, B, C, D, E, F, H, L, AF, BC, DE, HL, PC, SP };

pub fn reg_is_u8(reg: RegisterType) !bool {
    return switch (reg) {
        RegisterType.NONE => game_errors.EmuErrors.NotImplementedError,
        RegisterType.A => true,
        RegisterType.B => true,
        RegisterType.C => true,
        RegisterType.D => true,
        RegisterType.E => true,
        RegisterType.F => true,
        RegisterType.H => true,
        RegisterType.L => true,
        else => false,
    };
}

pub const ConditionType = enum {
    NONE,
    NZ,
    Z,
    NC,
    C,
    NH,
    H,
};

pub const Instruction = struct {
    in_type: InstructionType = InstructionType.NONE,
    mode: AddressMode = AddressMode.IMP,
    reg_1: RegisterType = RegisterType.NONE,
    reg_2: RegisterType = RegisterType.NONE,
    cond: ConditionType = ConditionType.NONE,
    param: u8 = 0x00,
};

pub fn GetInstructionMap() !std.AutoHashMap(u8, Instruction) {
    const allocator = game_allocator.GetAllocator();
    var instruction_map = std.AutoHashMap(u8, Instruction).init(allocator);

    //0x0
    try instruction_map.put(0x00, Instruction{ .in_type = InstructionType.NOP, .mode = AddressMode.IMP });
    try instruction_map.put(0x01, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_N16, .reg_1 = RegisterType.BC });
    try instruction_map.put(0x02, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.PTR_R, .reg_1 = RegisterType.BC, .reg_2 = RegisterType.A });
    try instruction_map.put(0x05, Instruction{ .in_type = InstructionType.DEC, .mode = AddressMode.R, .reg_1 = RegisterType.B });
    try instruction_map.put(0x06, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_N8, .reg_1 = RegisterType.B });
    try instruction_map.put(0x08, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.A16_R, .reg_2 = RegisterType.SP });
    try instruction_map.put(0x0A, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_PTR, .reg_1 = RegisterType.A, .reg_2 = RegisterType.BC });
    try instruction_map.put(0x0E, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_N8, .reg_1 = RegisterType.C });
    //0x1
    try instruction_map.put(0x11, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_N16, .reg_1 = RegisterType.DE });
    try instruction_map.put(0x12, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.PTR_R, .reg_1 = RegisterType.DE, .reg_2 = RegisterType.A });
    try instruction_map.put(0x15, Instruction{ .in_type = InstructionType.DEC, .mode = AddressMode.R, .reg_1 = RegisterType.D });
    //0x2
    try instruction_map.put(0x21, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_N16, .reg_1 = RegisterType.HL });
    try instruction_map.put(0x22, Instruction{ .in_type = InstructionType.LDI, .mode = AddressMode.PTR_R, .reg_1 = RegisterType.HL, .reg_2 = RegisterType.A });
    try instruction_map.put(0x25, Instruction{ .in_type = InstructionType.DEC, .mode = AddressMode.R, .reg_1 = RegisterType.H });
    //0x3
    try instruction_map.put(0x31, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_N16, .reg_1 = RegisterType.SP, .reg_2 = RegisterType.NONE });
    try instruction_map.put(0x32, Instruction{ .in_type = InstructionType.LDD, .mode = AddressMode.PTR_R, .reg_1 = RegisterType.HL, .reg_2 = RegisterType.A });
    try instruction_map.put(0x35, Instruction{ .in_type = InstructionType.DEC, .mode = AddressMode.PTR, .reg_1 = RegisterType.HL });
    try instruction_map.put(0x3E, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_N8, .reg_1 = RegisterType.A });
    //0x4
    try instruction_map.put(0x40, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.B, .reg_2 = RegisterType.B });
    try instruction_map.put(0x41, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.B, .reg_2 = RegisterType.C });
    try instruction_map.put(0x42, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.B, .reg_2 = RegisterType.D });
    try instruction_map.put(0x43, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.B, .reg_2 = RegisterType.E });
    try instruction_map.put(0x44, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.B, .reg_2 = RegisterType.H });
    try instruction_map.put(0x45, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.B, .reg_2 = RegisterType.L });
    try instruction_map.put(0x46, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_PTR, .reg_1 = RegisterType.B, .reg_2 = RegisterType.HL });
    try instruction_map.put(0x47, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.B, .reg_2 = RegisterType.A });
    try instruction_map.put(0x48, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.C, .reg_2 = RegisterType.B });
    try instruction_map.put(0x49, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.C, .reg_2 = RegisterType.C });
    try instruction_map.put(0x4A, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.C, .reg_2 = RegisterType.D });
    try instruction_map.put(0x4B, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.C, .reg_2 = RegisterType.E });
    try instruction_map.put(0x4C, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.C, .reg_2 = RegisterType.H });
    try instruction_map.put(0x4D, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.C, .reg_2 = RegisterType.L });
    try instruction_map.put(0x4E, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_PTR, .reg_1 = RegisterType.C, .reg_2 = RegisterType.HL });
    try instruction_map.put(0x4F, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.C, .reg_2 = RegisterType.A });
    //0x5
    try instruction_map.put(0x50, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.D, .reg_2 = RegisterType.B });
    try instruction_map.put(0x51, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.D, .reg_2 = RegisterType.C });
    try instruction_map.put(0x52, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.D, .reg_2 = RegisterType.D });
    try instruction_map.put(0x53, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.D, .reg_2 = RegisterType.E });
    try instruction_map.put(0x54, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.D, .reg_2 = RegisterType.H });
    try instruction_map.put(0x55, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.D, .reg_2 = RegisterType.L });
    try instruction_map.put(0x56, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_PTR, .reg_1 = RegisterType.D, .reg_2 = RegisterType.HL });
    try instruction_map.put(0x57, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.D, .reg_2 = RegisterType.A });
    try instruction_map.put(0x58, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.E, .reg_2 = RegisterType.B });
    try instruction_map.put(0x59, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.E, .reg_2 = RegisterType.C });
    try instruction_map.put(0x5A, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.E, .reg_2 = RegisterType.D });
    try instruction_map.put(0x5B, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.E, .reg_2 = RegisterType.E });
    try instruction_map.put(0x5C, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.E, .reg_2 = RegisterType.H });
    try instruction_map.put(0x5D, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.E, .reg_2 = RegisterType.L });
    try instruction_map.put(0x5E, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_PTR, .reg_1 = RegisterType.E, .reg_2 = RegisterType.HL });
    try instruction_map.put(0x5F, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.E, .reg_2 = RegisterType.A });
    //0x6
    try instruction_map.put(0x60, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.H, .reg_2 = RegisterType.B });
    try instruction_map.put(0x61, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.H, .reg_2 = RegisterType.C });
    try instruction_map.put(0x62, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.H, .reg_2 = RegisterType.D });
    try instruction_map.put(0x63, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.H, .reg_2 = RegisterType.E });
    try instruction_map.put(0x64, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.H, .reg_2 = RegisterType.H });
    try instruction_map.put(0x65, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.H, .reg_2 = RegisterType.L });
    try instruction_map.put(0x66, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_PTR, .reg_1 = RegisterType.H, .reg_2 = RegisterType.HL });
    try instruction_map.put(0x67, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.H, .reg_2 = RegisterType.A });
    try instruction_map.put(0x68, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.L, .reg_2 = RegisterType.B });
    try instruction_map.put(0x69, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.L, .reg_2 = RegisterType.C });
    try instruction_map.put(0x6A, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.L, .reg_2 = RegisterType.D });
    try instruction_map.put(0x6B, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.L, .reg_2 = RegisterType.E });
    try instruction_map.put(0x6C, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.L, .reg_2 = RegisterType.H });
    try instruction_map.put(0x6D, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.L, .reg_2 = RegisterType.L });
    try instruction_map.put(0x6E, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_PTR, .reg_1 = RegisterType.L, .reg_2 = RegisterType.HL });
    try instruction_map.put(0x6F, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.L, .reg_2 = RegisterType.A });

    //0x7
    try instruction_map.put(0x70, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.PTR_R, .reg_1 = RegisterType.HL, .reg_2 = RegisterType.B });
    try instruction_map.put(0x71, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.PTR_R, .reg_1 = RegisterType.HL, .reg_2 = RegisterType.C });
    try instruction_map.put(0x72, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.PTR_R, .reg_1 = RegisterType.HL, .reg_2 = RegisterType.D });
    try instruction_map.put(0x73, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.PTR_R, .reg_1 = RegisterType.HL, .reg_2 = RegisterType.E });
    try instruction_map.put(0x74, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.PTR_R, .reg_1 = RegisterType.HL, .reg_2 = RegisterType.H });
    try instruction_map.put(0x75, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.PTR_R, .reg_1 = RegisterType.HL, .reg_2 = RegisterType.L });
    try instruction_map.put(0x76, Instruction{ .in_type = InstructionType.HALT });
    try instruction_map.put(0x77, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.PTR_R, .reg_1 = RegisterType.HL, .reg_2 = RegisterType.A });
    try instruction_map.put(0x78, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.B });
    try instruction_map.put(0x79, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.C });
    try instruction_map.put(0x7A, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.D });
    try instruction_map.put(0x7B, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.E });
    try instruction_map.put(0x7C, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.H });
    try instruction_map.put(0x7D, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.L });
    try instruction_map.put(0x7E, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_PTR, .reg_1 = RegisterType.A, .reg_2 = RegisterType.HL });
    try instruction_map.put(0x7F, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.A });
    //0x8
    //0x9
    //0xA
    try instruction_map.put(0xAF, Instruction{ .in_type = InstructionType.XOR, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.A });
    //0xB
    //0xC
    try instruction_map.put(0xC3, Instruction{ .in_type = InstructionType.JP, .mode = AddressMode.N16 });
    try instruction_map.put(0xCD, Instruction{ .in_type = InstructionType.CALL, .mode = AddressMode.N16 });
    //0xD
    //0xE
    try instruction_map.put(0xE0, Instruction{ .in_type = InstructionType.LDH, .mode = AddressMode.A8_R, .reg_2 = RegisterType.A });
    try instruction_map.put(0xEA, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.A16_R, .reg_2 = RegisterType.A });
    //0xF
    try instruction_map.put(0xF0, Instruction{ .in_type = InstructionType.LDH, .mode = AddressMode.R_A8, .reg_1 = RegisterType.A });
    try instruction_map.put(0xF3, Instruction{ .in_type = InstructionType.DI });

    return instruction_map;
}
