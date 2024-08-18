const std = @import("std");
const game_allocator = @import("game_allocator.zig");
const game_errors = @import("game_errors.zig");

pub const InstructionType = enum {
    NONE,
    NOP,
    LD,
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
    R_N16,
    R_R,
    PTR_R,
    R,
    R_N8,
    R_PTR,
    N16,
    N16_R,
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

    try instruction_map.put(0x00, Instruction{ .in_type = InstructionType.NOP, .mode = AddressMode.IMP });
    try instruction_map.put(0x31, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.N16, .reg_1 = RegisterType.SP, .reg_2 = RegisterType.NONE });
    try instruction_map.put(0x3E, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.R_N8, .reg_1 = RegisterType.A });
    try instruction_map.put(0xC3, Instruction{ .in_type = InstructionType.JP, .mode = AddressMode.N16 });
    try instruction_map.put(0xCD, Instruction{ .in_type = InstructionType.CALL, .mode = AddressMode.N16 });
    try instruction_map.put(0xEA, Instruction{ .in_type = InstructionType.LD, .mode = AddressMode.PTR_R, .reg_1 = RegisterType.NONE, .reg_2 = RegisterType.A });
    try instruction_map.put(0xF3, Instruction{ .in_type = InstructionType.DI });

    return instruction_map;
}
