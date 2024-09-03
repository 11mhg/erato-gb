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
    //RLC,
    //RRC,
    //RL,
    //RR,
    //SLA,
    //SRA,
    //SWAP,
    //SRL,
    //RES,
    //SET,
};

pub const AddressMode = enum {
    IMP,
    R,
    N8,
    N16,
    PTR,
    PTR_R,
    PTR_N8,
    R_R,
    R_N8,
    R_N16,
    R_PTR,
    R_A8,
    R_A16,
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

pub fn decode_register(reg_num: u3) RegisterType {
    return switch (reg_num) {
        0 => RegisterType.B,
        1 => RegisterType.C,
        2 => RegisterType.D,
        3 => RegisterType.E,
        4 => RegisterType.H,
        5 => RegisterType.L,
        6 => RegisterType.HL,
        7 => RegisterType.A,
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
    try instruction_map.put(0x03, Instruction{ .in_type = InstructionType.INC, .mode = AddressMode.R, .reg_1 = RegisterType.BC });
    try instruction_map.put(0x04, Instruction{ .in_type = InstructionType.INC, .mode = AddressMode.R, .reg_1 = RegisterType.B });
    try instruction_map.put(0x05, Instruction{ .in_type = InstructionType.DEC, .mode = AddressMode.R, .reg_1 = RegisterType.B });
    try instruction_map.put(0x06, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_N8, .reg_1 = RegisterType.B });
    try instruction_map.put(0x07, Instruction{ .in_type = InstructionType.RLCA, .mode = AddressMode.IMP });
    try instruction_map.put(0x08, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.A16_R, .reg_2 = RegisterType.SP });
    try instruction_map.put(0x09, Instruction{ .in_type = InstructionType.ADD, .mode = AddressMode.R_R, .reg_1 = RegisterType.HL, .reg_2 = RegisterType.BC });
    try instruction_map.put(0x0A, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_PTR, .reg_1 = RegisterType.A, .reg_2 = RegisterType.BC });
    try instruction_map.put(0x0B, Instruction{ .in_type = InstructionType.DEC, .mode = AddressMode.R, .reg_1 = RegisterType.BC });
    try instruction_map.put(0x0C, Instruction{ .in_type = InstructionType.INC, .mode = AddressMode.R, .reg_1 = RegisterType.C });
    try instruction_map.put(0x0D, Instruction{ .in_type = InstructionType.DEC, .mode = AddressMode.R, .reg_1 = RegisterType.C });
    try instruction_map.put(0x0E, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_N8, .reg_1 = RegisterType.C });
    try instruction_map.put(0x0F, Instruction{ .in_type = InstructionType.RRCA, .mode = AddressMode.IMP });
    //0x1
    try instruction_map.put(0x10, Instruction{ .in_type = InstructionType.STOP, .mode = AddressMode.N8 });
    try instruction_map.put(0x11, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_N16, .reg_1 = RegisterType.DE });
    try instruction_map.put(0x12, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.PTR_R, .reg_1 = RegisterType.DE, .reg_2 = RegisterType.A });
    try instruction_map.put(0x13, Instruction{ .in_type = InstructionType.INC, .mode = AddressMode.R, .reg_1 = RegisterType.DE });
    try instruction_map.put(0x14, Instruction{ .in_type = InstructionType.INC, .mode = AddressMode.R, .reg_1 = RegisterType.D });
    try instruction_map.put(0x15, Instruction{ .in_type = InstructionType.DEC, .mode = AddressMode.R, .reg_1 = RegisterType.D });
    try instruction_map.put(0x16, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_N8, .reg_1 = RegisterType.D });
    try instruction_map.put(0x17, Instruction{ .in_type = InstructionType.RLA, .mode = AddressMode.IMP });
    try instruction_map.put(0x18, Instruction{ .in_type = InstructionType.JR, .mode = AddressMode.N8, .cond = ConditionType.NONE });
    try instruction_map.put(0x19, Instruction{ .in_type = InstructionType.ADD, .mode = AddressMode.R_R, .reg_1 = RegisterType.HL, .reg_2 = RegisterType.DE });
    try instruction_map.put(0x1A, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_PTR, .reg_1 = RegisterType.A, .reg_2 = RegisterType.DE });
    try instruction_map.put(0x1B, Instruction{ .in_type = InstructionType.DEC, .mode = AddressMode.R, .reg_1 = RegisterType.DE });
    try instruction_map.put(0x1C, Instruction{ .in_type = InstructionType.INC, .mode = AddressMode.R, .reg_1 = RegisterType.E });
    try instruction_map.put(0x1D, Instruction{ .in_type = InstructionType.DEC, .mode = AddressMode.R, .reg_1 = RegisterType.E });
    try instruction_map.put(0x1E, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_N8, .reg_1 = RegisterType.E });
    try instruction_map.put(0x1F, Instruction{ .in_type = InstructionType.RRA, .mode = AddressMode.IMP });
    //0x2
    try instruction_map.put(0x20, Instruction{ .in_type = InstructionType.JR, .mode = AddressMode.N8, .cond = ConditionType.NZ });
    try instruction_map.put(0x21, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_N16, .reg_1 = RegisterType.HL });
    try instruction_map.put(0x22, Instruction{ .in_type = InstructionType.LDI, .mode = AddressMode.PTR_R, .reg_1 = RegisterType.HL, .reg_2 = RegisterType.A });
    try instruction_map.put(0x23, Instruction{ .in_type = InstructionType.INC, .mode = AddressMode.R, .reg_1 = RegisterType.HL });
    try instruction_map.put(0x24, Instruction{ .in_type = InstructionType.INC, .mode = AddressMode.R, .reg_1 = RegisterType.H });
    try instruction_map.put(0x25, Instruction{ .in_type = InstructionType.DEC, .mode = AddressMode.R, .reg_1 = RegisterType.H });
    try instruction_map.put(0x26, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_N8, .reg_1 = RegisterType.H });
    try instruction_map.put(0x27, Instruction{ .in_type = InstructionType.DAA, .mode = AddressMode.IMP });
    try instruction_map.put(0x28, Instruction{ .in_type = InstructionType.JR, .mode = AddressMode.N8, .cond = ConditionType.Z });
    try instruction_map.put(0x29, Instruction{ .in_type = InstructionType.ADD, .mode = AddressMode.R_R, .reg_1 = RegisterType.HL, .reg_2 = RegisterType.HL });
    try instruction_map.put(0x2A, Instruction{ .in_type = InstructionType.LDI, .mode = AddressMode.R_PTR, .reg_1 = RegisterType.A, .reg_2 = RegisterType.HL });
    try instruction_map.put(0x2B, Instruction{ .in_type = InstructionType.DEC, .mode = AddressMode.R, .reg_1 = RegisterType.HL });
    try instruction_map.put(0x2C, Instruction{ .in_type = InstructionType.INC, .mode = AddressMode.R, .reg_1 = RegisterType.L });
    try instruction_map.put(0x2D, Instruction{ .in_type = InstructionType.DEC, .mode = AddressMode.R, .reg_1 = RegisterType.L });
    try instruction_map.put(0x2E, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_N8, .reg_1 = RegisterType.L });
    try instruction_map.put(0x2F, Instruction{ .in_type = InstructionType.CPL, .mode = AddressMode.IMP });
    //0x3
    try instruction_map.put(0x30, Instruction{ .in_type = InstructionType.JR, .mode = AddressMode.N8, .cond = ConditionType.NC });
    try instruction_map.put(0x31, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_N16, .reg_1 = RegisterType.SP, .reg_2 = RegisterType.NONE });
    try instruction_map.put(0x32, Instruction{ .in_type = InstructionType.LDD, .mode = AddressMode.PTR_R, .reg_1 = RegisterType.HL, .reg_2 = RegisterType.A });
    try instruction_map.put(0x33, Instruction{ .in_type = InstructionType.INC, .mode = AddressMode.R, .reg_1 = RegisterType.SP });
    try instruction_map.put(0x34, Instruction{ .in_type = InstructionType.INC, .mode = AddressMode.PTR, .reg_1 = RegisterType.HL });
    try instruction_map.put(0x35, Instruction{ .in_type = InstructionType.DEC, .mode = AddressMode.PTR, .reg_1 = RegisterType.HL });
    try instruction_map.put(0x36, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.PTR_N8, .reg_1 = RegisterType.HL });
    try instruction_map.put(0x37, Instruction{ .in_type = InstructionType.SCF, .mode = AddressMode.IMP });
    try instruction_map.put(0x38, Instruction{ .in_type = InstructionType.JR, .mode = AddressMode.N8, .cond = ConditionType.C });
    try instruction_map.put(0x39, Instruction{ .in_type = InstructionType.ADD, .mode = AddressMode.R_R, .reg_1 = RegisterType.HL, .reg_2 = RegisterType.SP });
    try instruction_map.put(0x3A, Instruction{ .in_type = InstructionType.LDD, .mode = AddressMode.R_PTR, .reg_1 = RegisterType.A, .reg_2 = RegisterType.HL });
    try instruction_map.put(0x3B, Instruction{ .in_type = InstructionType.DEC, .mode = AddressMode.R, .reg_1 = RegisterType.SP });
    try instruction_map.put(0x3C, Instruction{ .in_type = InstructionType.INC, .mode = AddressMode.R, .reg_1 = RegisterType.A });
    try instruction_map.put(0x3D, Instruction{ .in_type = InstructionType.DEC, .mode = AddressMode.R, .reg_1 = RegisterType.A });
    try instruction_map.put(0x3E, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_N8, .reg_1 = RegisterType.A });
    try instruction_map.put(0x3F, Instruction{ .in_type = InstructionType.CCF, .mode = AddressMode.IMP });
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
    try instruction_map.put(0x80, Instruction{ .in_type = InstructionType.ADD, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.B });
    try instruction_map.put(0x81, Instruction{ .in_type = InstructionType.ADD, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.C });
    try instruction_map.put(0x82, Instruction{ .in_type = InstructionType.ADD, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.D });
    try instruction_map.put(0x83, Instruction{ .in_type = InstructionType.ADD, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.E });
    try instruction_map.put(0x84, Instruction{ .in_type = InstructionType.ADD, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.H });
    try instruction_map.put(0x85, Instruction{ .in_type = InstructionType.ADD, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.L });
    try instruction_map.put(0x86, Instruction{ .in_type = InstructionType.ADD, .mode = AddressMode.R_PTR, .reg_1 = RegisterType.A, .reg_2 = RegisterType.HL });
    try instruction_map.put(0x87, Instruction{ .in_type = InstructionType.ADD, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.A });
    try instruction_map.put(0x88, Instruction{ .in_type = InstructionType.ADC, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.B });
    try instruction_map.put(0x89, Instruction{ .in_type = InstructionType.ADC, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.C });
    try instruction_map.put(0x8A, Instruction{ .in_type = InstructionType.ADC, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.D });
    try instruction_map.put(0x8B, Instruction{ .in_type = InstructionType.ADC, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.E });
    try instruction_map.put(0x8C, Instruction{ .in_type = InstructionType.ADC, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.H });
    try instruction_map.put(0x8D, Instruction{ .in_type = InstructionType.ADC, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.L });
    try instruction_map.put(0x8E, Instruction{ .in_type = InstructionType.ADC, .mode = AddressMode.R_PTR, .reg_1 = RegisterType.A, .reg_2 = RegisterType.HL });
    try instruction_map.put(0x8F, Instruction{ .in_type = InstructionType.ADC, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.A });
    //0x9
    try instruction_map.put(0x90, Instruction{ .in_type = InstructionType.SUB, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.B });
    try instruction_map.put(0x91, Instruction{ .in_type = InstructionType.SUB, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.C });
    try instruction_map.put(0x92, Instruction{ .in_type = InstructionType.SUB, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.D });
    try instruction_map.put(0x93, Instruction{ .in_type = InstructionType.SUB, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.E });
    try instruction_map.put(0x94, Instruction{ .in_type = InstructionType.SUB, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.H });
    try instruction_map.put(0x95, Instruction{ .in_type = InstructionType.SUB, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.L });
    try instruction_map.put(0x96, Instruction{ .in_type = InstructionType.SUB, .mode = AddressMode.R_PTR, .reg_1 = RegisterType.A, .reg_2 = RegisterType.HL });
    try instruction_map.put(0x97, Instruction{ .in_type = InstructionType.SUB, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.A });
    try instruction_map.put(0x98, Instruction{ .in_type = InstructionType.SBC, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.B });
    try instruction_map.put(0x99, Instruction{ .in_type = InstructionType.SBC, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.C });
    try instruction_map.put(0x9A, Instruction{ .in_type = InstructionType.SBC, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.D });
    try instruction_map.put(0x9B, Instruction{ .in_type = InstructionType.SBC, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.E });
    try instruction_map.put(0x9C, Instruction{ .in_type = InstructionType.SBC, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.H });
    try instruction_map.put(0x9D, Instruction{ .in_type = InstructionType.SBC, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.L });
    try instruction_map.put(0x9E, Instruction{ .in_type = InstructionType.SBC, .mode = AddressMode.R_PTR, .reg_1 = RegisterType.A, .reg_2 = RegisterType.HL });
    try instruction_map.put(0x9F, Instruction{ .in_type = InstructionType.SBC, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.A });
    //0xA
    try instruction_map.put(0xA0, Instruction{ .in_type = InstructionType.AND, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.B });
    try instruction_map.put(0xA1, Instruction{ .in_type = InstructionType.AND, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.C });
    try instruction_map.put(0xA2, Instruction{ .in_type = InstructionType.AND, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.D });
    try instruction_map.put(0xA3, Instruction{ .in_type = InstructionType.AND, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.E });
    try instruction_map.put(0xA4, Instruction{ .in_type = InstructionType.AND, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.H });
    try instruction_map.put(0xA5, Instruction{ .in_type = InstructionType.AND, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.L });
    try instruction_map.put(0xA6, Instruction{ .in_type = InstructionType.AND, .mode = AddressMode.R_PTR, .reg_1 = RegisterType.A, .reg_2 = RegisterType.HL });
    try instruction_map.put(0xA7, Instruction{ .in_type = InstructionType.AND, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.A });
    try instruction_map.put(0xA8, Instruction{ .in_type = InstructionType.XOR, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.B });
    try instruction_map.put(0xA9, Instruction{ .in_type = InstructionType.XOR, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.C });
    try instruction_map.put(0xAA, Instruction{ .in_type = InstructionType.XOR, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.D });
    try instruction_map.put(0xAB, Instruction{ .in_type = InstructionType.XOR, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.E });
    try instruction_map.put(0xAC, Instruction{ .in_type = InstructionType.XOR, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.H });
    try instruction_map.put(0xAD, Instruction{ .in_type = InstructionType.XOR, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.L });
    try instruction_map.put(0xAE, Instruction{ .in_type = InstructionType.XOR, .mode = AddressMode.R_PTR, .reg_1 = RegisterType.A, .reg_2 = RegisterType.HL });
    try instruction_map.put(0xAF, Instruction{ .in_type = InstructionType.XOR, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.A });
    //0xB
    try instruction_map.put(0xB0, Instruction{ .in_type = InstructionType.OR, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.B });
    try instruction_map.put(0xB1, Instruction{ .in_type = InstructionType.OR, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.C });
    try instruction_map.put(0xB2, Instruction{ .in_type = InstructionType.OR, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.D });
    try instruction_map.put(0xB3, Instruction{ .in_type = InstructionType.OR, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.E });
    try instruction_map.put(0xB4, Instruction{ .in_type = InstructionType.OR, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.H });
    try instruction_map.put(0xB5, Instruction{ .in_type = InstructionType.OR, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.L });
    try instruction_map.put(0xB6, Instruction{ .in_type = InstructionType.OR, .mode = AddressMode.R_PTR, .reg_1 = RegisterType.A, .reg_2 = RegisterType.HL });
    try instruction_map.put(0xB7, Instruction{ .in_type = InstructionType.OR, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.A });
    try instruction_map.put(0xB8, Instruction{ .in_type = InstructionType.CP, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.B });
    try instruction_map.put(0xB9, Instruction{ .in_type = InstructionType.CP, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.C });
    try instruction_map.put(0xBA, Instruction{ .in_type = InstructionType.CP, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.D });
    try instruction_map.put(0xBB, Instruction{ .in_type = InstructionType.CP, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.E });
    try instruction_map.put(0xBC, Instruction{ .in_type = InstructionType.CP, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.H });
    try instruction_map.put(0xBD, Instruction{ .in_type = InstructionType.CP, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.L });
    try instruction_map.put(0xBE, Instruction{ .in_type = InstructionType.CP, .mode = AddressMode.R_PTR, .reg_1 = RegisterType.A, .reg_2 = RegisterType.HL });
    try instruction_map.put(0xBF, Instruction{ .in_type = InstructionType.CP, .mode = AddressMode.R_R, .reg_1 = RegisterType.A, .reg_2 = RegisterType.A });
    //0xC
    try instruction_map.put(0xC0, Instruction{ .in_type = InstructionType.RET, .mode = AddressMode.IMP, .cond = ConditionType.NZ });
    try instruction_map.put(0xC1, Instruction{ .in_type = InstructionType.POP, .mode = AddressMode.R, .reg_1 = RegisterType.BC });
    try instruction_map.put(0xC2, Instruction{ .in_type = InstructionType.JP, .mode = AddressMode.N16, .cond = ConditionType.NZ });
    try instruction_map.put(0xC3, Instruction{ .in_type = InstructionType.JP, .mode = AddressMode.N16 });
    try instruction_map.put(0xC4, Instruction{ .in_type = InstructionType.CALL, .mode = AddressMode.N16, .cond = ConditionType.NZ });
    try instruction_map.put(0xC5, Instruction{ .in_type = InstructionType.PUSH, .mode = AddressMode.R, .reg_1 = RegisterType.BC });
    try instruction_map.put(0xC6, Instruction{ .in_type = InstructionType.ADD, .mode = AddressMode.R_N8, .reg_1 = RegisterType.A });
    try instruction_map.put(0xC7, Instruction{ .in_type = InstructionType.RST, .param = 0x00 });
    try instruction_map.put(0xC8, Instruction{ .in_type = InstructionType.RET, .mode = AddressMode.IMP, .cond = ConditionType.Z });
    try instruction_map.put(0xC9, Instruction{ .in_type = InstructionType.RET, .mode = AddressMode.IMP, .cond = ConditionType.NONE });
    try instruction_map.put(0xCA, Instruction{ .in_type = InstructionType.JP, .mode = AddressMode.N16, .cond = ConditionType.Z });
    try instruction_map.put(0xCB, Instruction{ .in_type = InstructionType.CB, .mode = AddressMode.N8 });
    try instruction_map.put(0xCC, Instruction{ .in_type = InstructionType.CALL, .mode = AddressMode.N16, .cond = ConditionType.Z });
    try instruction_map.put(0xCD, Instruction{ .in_type = InstructionType.CALL, .mode = AddressMode.N16 });
    try instruction_map.put(0xCE, Instruction{ .in_type = InstructionType.ADC, .mode = AddressMode.R_N8, .reg_1 = RegisterType.A });
    try instruction_map.put(0xCF, Instruction{ .in_type = InstructionType.RST, .param = 0x08 });
    //0xD
    try instruction_map.put(0xD0, Instruction{ .in_type = InstructionType.RET, .mode = AddressMode.IMP, .cond = ConditionType.NC });
    try instruction_map.put(0xD1, Instruction{ .in_type = InstructionType.POP, .mode = AddressMode.R, .reg_1 = RegisterType.DE });
    try instruction_map.put(0xD2, Instruction{ .in_type = InstructionType.JP, .mode = AddressMode.N16, .cond = ConditionType.NC });
    try instruction_map.put(0xD4, Instruction{ .in_type = InstructionType.CALL, .mode = AddressMode.N16, .cond = ConditionType.NC });
    try instruction_map.put(0xD5, Instruction{ .in_type = InstructionType.PUSH, .mode = AddressMode.R, .reg_1 = RegisterType.DE });
    try instruction_map.put(0xD6, Instruction{ .in_type = InstructionType.SUB, .mode = AddressMode.R_N8, .reg_1 = RegisterType.A });
    try instruction_map.put(0xD7, Instruction{ .in_type = InstructionType.RST, .param = 0x10 });
    try instruction_map.put(0xD8, Instruction{ .in_type = InstructionType.RET, .mode = AddressMode.IMP, .cond = ConditionType.C });
    try instruction_map.put(0xD9, Instruction{ .in_type = InstructionType.RETI, .mode = AddressMode.IMP, .cond = ConditionType.NONE });
    try instruction_map.put(0xDA, Instruction{ .in_type = InstructionType.JP, .mode = AddressMode.N16, .cond = ConditionType.C });
    try instruction_map.put(0xDC, Instruction{ .in_type = InstructionType.CALL, .mode = AddressMode.N16, .cond = ConditionType.C });
    try instruction_map.put(0xDE, Instruction{ .in_type = InstructionType.SBC, .mode = AddressMode.R_N8, .reg_1 = RegisterType.A });
    try instruction_map.put(0xDF, Instruction{ .in_type = InstructionType.RST, .param = 0x18 });
    //0xE
    try instruction_map.put(0xE0, Instruction{ .in_type = InstructionType.LDH, .mode = AddressMode.A8_R, .reg_2 = RegisterType.A });
    try instruction_map.put(0xE1, Instruction{ .in_type = InstructionType.POP, .mode = AddressMode.R, .reg_1 = RegisterType.HL });
    try instruction_map.put(0xE2, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.PTR_R, .reg_1 = RegisterType.C, .reg_2 = RegisterType.A });

    try instruction_map.put(0xE5, Instruction{ .in_type = InstructionType.PUSH, .mode = AddressMode.R, .reg_1 = RegisterType.HL });
    try instruction_map.put(0xE6, Instruction{ .in_type = InstructionType.AND, .mode = AddressMode.R_N8, .reg_1 = RegisterType.A });
    try instruction_map.put(0xE7, Instruction{ .in_type = InstructionType.RST, .param = 0x20 });
    try instruction_map.put(0xE8, Instruction{ .in_type = InstructionType.ADD, .mode = AddressMode.R_N8, .reg_1 = RegisterType.SP });
    try instruction_map.put(0xE9, Instruction{ .in_type = InstructionType.JP, .mode = AddressMode.R, .reg_1 = RegisterType.HL });
    try instruction_map.put(0xEA, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.A16_R, .reg_2 = RegisterType.A });

    try instruction_map.put(0xEE, Instruction{ .in_type = InstructionType.XOR, .mode = AddressMode.R_N8, .reg_1 = RegisterType.A });
    try instruction_map.put(0xEF, Instruction{ .in_type = InstructionType.RST, .param = 0x28 });
    //0xF
    try instruction_map.put(0xF0, Instruction{ .in_type = InstructionType.LDH, .mode = AddressMode.R_A8, .reg_1 = RegisterType.A });
    try instruction_map.put(0xF1, Instruction{ .in_type = InstructionType.POP, .mode = AddressMode.R, .reg_1 = RegisterType.AF });
    try instruction_map.put(0xF2, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_PTR, .reg_1 = RegisterType.A, .reg_2 = RegisterType.C });
    try instruction_map.put(0xF3, Instruction{ .in_type = InstructionType.DI });

    try instruction_map.put(0xF5, Instruction{ .in_type = InstructionType.PUSH, .mode = AddressMode.R, .reg_1 = RegisterType.AF });
    try instruction_map.put(0xF6, Instruction{ .in_type = InstructionType.OR, .mode = AddressMode.R_N8, .reg_1 = RegisterType.A });
    try instruction_map.put(0xF7, Instruction{ .in_type = InstructionType.RST, .param = 0x30 });

    try instruction_map.put(0xF8, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_N8, .reg_1 = RegisterType.HL, .reg_2 = RegisterType.SP });
    try instruction_map.put(0xF9, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_R, .reg_1 = RegisterType.SP, .reg_2 = RegisterType.HL });
    try instruction_map.put(0xFA, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_A16, .reg_1 = RegisterType.A });
    try instruction_map.put(0xFB, Instruction{ .in_type = InstructionType.EI, .mode = AddressMode.IMP });

    try instruction_map.put(0xFE, Instruction{ .in_type = InstructionType.CP, .mode = AddressMode.R_N8, .reg_1 = RegisterType.A });
    try instruction_map.put(0xFF, Instruction{ .in_type = InstructionType.RST, .param = 0x38 });
    return instruction_map;
}

pub fn GetPrefixedInstructionMap() !std.AutoHashMap(u8, Instruction) {
    const allocator = game_allocator.GetAllocator();
    const instruction_map = std.AutoHashMap(u8, Instruction).init(allocator);

    return instruction_map;
}
