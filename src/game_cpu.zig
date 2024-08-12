const std = @import("std");
const game_allocator = @import("game_allocator.zig");
const game_memory = @import("game_memory.zig");

pub const FlagRegister = packed struct(u8) {
    _: u4,
    carry: bool,
    half_carry: bool,
    subtract: bool,
    zero: bool,
};

pub const Registers = packed struct {
    a: u8,
    b: u8,
    c: u8,
    d: u8,
    e: u8,
    f: u8,
    h: u8,
    l: u8,
    pub fn get_af(self: *Registers) u16 {
        return (@as(u16, self.a) << 8) | (@as(u16, self.f));
    }
    pub fn get_bc(self: *Registers) u16 {
        return (@as(u16, self.b) << 8) | (@as(u16, self.c));
    }
    pub fn get_de(self: *Registers) u16 {
        return (@as(u16, self.d) << 8) | (@as(u16, self.e));
    }
    pub fn get_hl(self: *Registers) u16 {
        return (@as(u16, self.h) << 8) | (@as(u16, self.l));
    }
    pub fn set_af(self: *Registers, value: u16) void {
        self.a = @truncate((value & 0xFF00) >> 8);
        self.f = @truncate((value & 0x00FF));
    }
    pub fn set_bc(self: *Registers, value: u16) void {
        self.b = @truncate((value & 0xFF00) >> 8);
        self.c = @truncate((value & 0x00FF));
    }
    pub fn set_de(self: *Registers, value: u16) void {
        self.d = @truncate((value & 0xFF00) >> 8);
        self.e = @truncate((value & 0x00FF));
    }
    pub fn set_hl(self: *Registers, value: u16) void {
        self.h = @truncate((value & 0xFF00) >> 8);
        self.l = @truncate((value & 0x00FF));
    }
};

pub const RegisterNames = enum { NONE, A, B, C, D, E, H, L, AF, BC, DE, HL };

pub const Instruction = enum {
    NOP,
    ADD,
    ADDHL,
    ADC,
    SUB,
    SBC,
    AND,
    OR,
    XOR,
    CP,
    INC,
    DEC,
    CCF,
    SCF,
    RRA,
    RLA,
    RRCA,
    RLCA,
    CPL,
    BIT,
    RES,
};

const CPUErrors = error{
    OpNotImplemented,
    OpImplementedTargetNotImplemented,
};

const CPU = struct {
    registers: Registers,
    sp: u16,
    pc: u16,
    memoryBus: game_memory.MemoryBus,

    fn fetch_register_u16(self: *CPU, targetRegister: RegisterNames) !u16 {
        switch (targetRegister) {
            RegisterNames.A => {
                return @as(u16, self.registers.a);
            },
            RegisterNames.B => {
                return @as(u16, self.registers.b);
            },
            RegisterNames.C => {
                return @as(u16, self.registers.c);
            },
            RegisterNames.D => {
                return @as(u16, self.registers.d);
            },
            RegisterNames.E => {
                return @as(u16, self.registers.e);
            },
            RegisterNames.H => {
                return @as(u16, self.registers.h);
            },
            RegisterNames.L => {
                return @as(u16, self.registers.l);
            },
            RegisterNames.AF => {
                return self.registers.get_af();
            },
            RegisterNames.BC => {
                return self.registers.get_bc();
            },
            RegisterNames.DE => {
                return self.registers.get_de();
            },
            RegisterNames.HL => {
                return self.registers.get_hl();
            },
            else => {
                return CPUErrors.OpImplementedTargetNotImplemented;
            },
        }
    }
    fn fetch_register_u8(self: *CPU, targetRegister: RegisterNames) !u8 {
        switch (targetRegister) {
            RegisterNames.A => {
                return self.registers.a;
            },
            RegisterNames.B => {
                return self.registers.b;
            },
            RegisterNames.C => {
                return self.registers.c;
            },
            RegisterNames.D => {
                return self.registers.d;
            },
            RegisterNames.E => {
                return self.registers.e;
            },
            RegisterNames.H => {
                return self.registers.h;
            },
            RegisterNames.L => {
                return self.registers.l;
            },
            RegisterNames.AF => {
                return @truncate(self.registers.get_af());
            },
            RegisterNames.BC => {
                return @truncate(self.registers.get_bc());
            },
            RegisterNames.DE => {
                return @truncate(self.registers.get_de());
            },
            RegisterNames.HL => {
                return @truncate(self.registers.get_hl());
            },
            else => {
                return CPUErrors.OpImplementedTargetNotImplemented;
            },
        }
    }
    fn set_register_u8(self: *CPU, targetRegister: RegisterNames, value: u8) !void {
        switch (targetRegister) {
            RegisterNames.A => {
                self.registers.a = value;
            },
            RegisterNames.B => {
                self.registers.b = value;
            },
            RegisterNames.C => {
                self.registers.c = value;
            },
            RegisterNames.D => {
                self.registers.d = value;
            },
            RegisterNames.E => {
                self.registers.e = value;
            },
            RegisterNames.H => {
                self.registers.h = value;
            },
            RegisterNames.L => {
                self.registers.l = value;
            },
            RegisterNames.AF => {
                self.registers.set_af(value);
            },
            RegisterNames.BC => {
                self.registers.set_bc(value);
            },
            RegisterNames.DE => {
                self.registers.set_de(value);
            },
            RegisterNames.HL => {
                self.registers.set_hl(value);
            },
            else => {
                return CPUErrors.OpImplementedTargetNotImplemented;
            },
        }
    }

    fn execute(self: *CPU, instruction: Instruction, targetRegister: RegisterNames, _u3_val: u3) !void {
        var f: *FlagRegister = @ptrCast(&self.registers.f);
        switch (instruction) {
            Instruction.NOP => {},
            Instruction.ADD => {
                const value = try self.fetch_register_u8(targetRegister);
                const new_value = self._add(value);
                self.registers.a = new_value;
            },
            Instruction.ADDHL => {
                const value = try self.fetch_register_u16(targetRegister);
                const new_value = self._add_hl(value);
                self.registers.set_hl(new_value);
            },
            Instruction.ADC => {
                const value = try self.fetch_register_u8(targetRegister);
                const new_value = self._add_carry(value);
                self.registers.a = new_value;
            },
            Instruction.AND => {
                const value = try self.fetch_register_u8(targetRegister);
                const new_value = self._and(value);
                self.registers.a = new_value;
            },
            Instruction.SUB => {
                const value = try self.fetch_register_u8(targetRegister);
                const new_value = self._sub(value);
                self.registers.a = new_value;
            },
            Instruction.SBC => {
                const value = try self.fetch_register_u8(targetRegister);
                const new_value = self._sub_carry(value);
                self.registers.a = new_value;
            },
            Instruction.OR => {
                const value = try self.fetch_register_u8(targetRegister);
                const new_value = self._or(value);
                self.registers.a = new_value;
            },
            Instruction.XOR => {
                const value = try self.fetch_register_u8(targetRegister);
                const new_value = self._xor(value);
                self.registers.a = new_value;
            },
            Instruction.CP => {
                const value = try self.fetch_register_u8(targetRegister);
                _ = self._sub(value);
            },
            Instruction.INC => {
                const value = try self.fetch_register_u8(targetRegister);
                const new_value = self._inc(value);
                try self.set_register_u8(targetRegister, new_value);
            },
            Instruction.DEC => {
                const value = try self.fetch_register_u8(targetRegister);
                const new_value = self._dec(value);
                try self.set_register_u8(targetRegister, new_value);
            },
            Instruction.CCF => {
                f.subtract = false;
                f.half_carry = false;
                f.carry = !f.carry;
            },
            Instruction.SCF => {
                f.subtract = false;
                f.half_carry = false;
                f.carry = true;
            },
            Instruction.RRA => {
                self._rra();
            },
            Instruction.RLA => {
                self._rla();
            },
            Instruction.RRCA => {
                self._rrca();
            },
            Instruction.RLCA => {
                self._rlca();
            },
            Instruction.CPL => {
                self._cpl();
            },
            Instruction.BIT => {
                const value = try self.fetch_register_u8(targetRegister);
                self._bit(value, _u3_val);
            },
            Instruction.RES => {
                const value = try self.fetch_register_u8(targetRegister);
                const new_value = self._res(value, _u3_val);
                try self.set_register_u8(targetRegister, new_value);
            },
        }
    }

    fn _res(_: *CPU, value: u8, _u3_val: u3) u8 {
        const mask = ~(@as(u8, 1) << _u3_val);
        const new_value = value & mask;
        return new_value;
    }

    fn _bit(self: *CPU, value: u8, _u3_val: u3) void {
        var f: *FlagRegister = @ptrCast(&self.registers.f);
        const mask = @as(u8, 1) << _u3_val;

        f.zero = (value & mask) == 0;
        f.subtract = false;
        f.half_carry = true;
    }

    fn _cpl(self: *CPU) void {
        var f: *FlagRegister = @ptrCast(&self.registers.f);

        self.registers.a = ~self.registers.a;
        f.subtract = true;
        f.half_carry = true;
    }

    fn _rlca(self: *CPU) void {
        var f: *FlagRegister = @ptrCast(&self.registers.f);
        const most_bit = self.registers.a >> 7;

        self.registers.a = self.registers.a << 1;
        self.registers.a = self.registers.a | most_bit;

        f.zero = false;
        f.subtract = false;
        f.half_carry = false;
        f.carry = most_bit != 0;
    }

    fn _rla(self: *CPU) void {
        var f: *FlagRegister = @ptrCast(&self.registers.f);
        const carry: u8 = @intFromBool(f.carry);
        const most_bit = self.registers.a >> 7;

        self.registers.a = self.registers.a << 1;
        self.registers.a = self.registers.a | carry;

        f.zero = self.registers.a == 0;
        f.subtract = false;
        f.half_carry = false;
        f.carry = most_bit != 0;
    }

    fn _rrca(self: *CPU) void {
        var f: *FlagRegister = @ptrCast(&self.registers.f);
        const least_bit = self.registers.a & 1;
        self.registers.a = self.registers.a >> 1;

        f.zero = false;
        f.subtract = false;
        f.half_carry = false;
        f.carry = least_bit != 0;
    }

    fn _rra(self: *CPU) void {
        var f: *FlagRegister = @ptrCast(&self.registers.f);
        const carry: u8 = @intFromBool(f.carry);
        const least_bit = self.registers.a & 1;

        self.registers.a = self.registers.a >> 1;
        self.registers.a = self.registers.a | (carry << 7);

        f.zero = self.registers.a == 0;
        f.subtract = false;
        f.half_carry = false;
        f.carry = least_bit != 0;
    }

    fn _dec(self: *CPU, value: u8) u8 {
        const sub_result = @subWithOverflow(value, 1);
        const new_value = sub_result[0];

        var f: *FlagRegister = @ptrCast(&self.registers.f);
        f.zero = new_value == 0;
        f.subtract = false;
        f.half_carry = (value & 0x0F) < (1 & 0x0F);
        f.carry = new_value > value;
        return new_value;
    }

    fn _inc(self: *CPU, value: u8) u8 {
        const add_result = @addWithOverflow(value, 1);
        const new_value = add_result[0];

        var f: *FlagRegister = @ptrCast(&self.registers.f);
        f.zero = new_value == 0;
        f.subtract = false;
        f.half_carry = (1 + (value & 0x07)) > 0x07;
        f.carry = value > new_value;
        return new_value;
    }

    fn _add(self: *CPU, value: u8) u8 {
        const add_result = @addWithOverflow(self.registers.a, value);
        const new_value = add_result[0];
        const overflow_flag = add_result[1];

        var f: *FlagRegister = @ptrCast(&self.registers.f);
        f.zero = new_value == 0;
        f.subtract = false;
        f.carry = overflow_flag != 0;
        f.half_carry = ((self.registers.a & 0x07) + (value & 0x07)) > 0x07;
        return new_value;
    }

    fn _add_carry(self: *CPU, value: u8) u8 {
        var f: *FlagRegister = @ptrCast(&self.registers.f);
        const carryValue: u8 = @intFromBool(f.carry);

        var add_result = @addWithOverflow(self.registers.a, value);
        var new_value = add_result[0];
        var overflow_flag = add_result[1];

        add_result = @addWithOverflow(new_value, carryValue);
        new_value = add_result[0];
        overflow_flag = overflow_flag | add_result[1];

        f.zero = new_value == 0;
        f.subtract = false;
        f.carry = overflow_flag != 0;
        f.half_carry = ((self.registers.a & 0x07) + (value & 0x07) + (carryValue & 0x07)) > 0x07;
        return new_value;
    }

    fn _and(self: *CPU, value: u8) u8 {
        const and_result = self.registers.a & value;

        var f: *FlagRegister = @ptrCast(&self.registers.f);
        f.zero = and_result == 0;
        f.subtract = false;
        f.half_carry = true;
        f.carry = false;
        return and_result;
    }

    fn _sub(self: *CPU, value: u8) u8 {
        const sub_result = @subWithOverflow(self.registers.a, value)[0];
        var f: *FlagRegister = @ptrCast(&self.registers.f);
        f.zero = sub_result == 0;
        f.subtract = true;
        f.half_carry = (self.registers.a & 0x0F) < (value & 0x0F);
        f.carry = value > self.registers.a;

        return sub_result;
    }

    fn _sub_carry(self: *CPU, value: u8) u8 {
        var f: *FlagRegister = @ptrCast(&self.registers.f);
        const carryValue: u8 = @intFromBool(f.carry);
        const sub_result = @subWithOverflow(self.registers.a, value + carryValue)[0];

        f.zero = sub_result == 0;
        f.subtract = true;
        f.half_carry = (self.registers.a & 0x0F) < (value & 0x0F);
        f.carry = (value + carryValue) > self.registers.a;
        return sub_result;
    }

    fn _or(self: *CPU, value: u8) u8 {
        const or_result = self.registers.a | value;

        var f: *FlagRegister = @ptrCast(&self.registers.f);
        f.zero = or_result == 0;
        f.subtract = false;
        f.half_carry = false;
        f.carry = false;
        return or_result;
    }

    fn _xor(self: *CPU, value: u8) u8 {
        const xor_result = (self.registers.a & ~value) | (~self.registers.a & value);

        var f: *FlagRegister = @ptrCast(&self.registers.f);
        f.zero = xor_result == 0;
        f.subtract = false;
        f.half_carry = false;
        f.carry = false;
        return xor_result;
    }

    fn _add_hl(self: *CPU, value: u16) u16 {
        const add_result = @addWithOverflow(self.registers.get_hl(), value);
        const new_value = add_result[0];
        const overflow_flag = add_result[1];

        var f: *FlagRegister = @ptrCast(&self.registers.f);
        f.zero = new_value == 0;
        f.subtract = false;
        f.carry = overflow_flag != 0;
        f.half_carry = ((self.registers.a & 0xFF) + (value & 0xFF)) > 0xFF;
        return new_value;
    }
};

pub fn CreateCpu() !CPU {
    const register: Registers = Registers{
        .a = 0,
        .b = 0,
        .c = 0,
        .d = 0,
        .e = 0,
        .f = 0,
        .h = 0,
        .l = 0,
    };

    const memoryBus: game_memory.MemoryBus = try game_memory.CreateMemoryBus();

    const cpu = CPU{
        .registers = register,
        .memoryBus = memoryBus,
        .sp = 0,
        .pc = 0,
    };

    return cpu;
}

// ----- TESTS -------
test "basic register functionality" {
    var register: Registers = Registers{
        .a = 0,
        .b = 0,
        .c = 0,
        .d = 0,
        .e = 0,
        .f = 0,
        .h = 0,
        .l = 0,
    };
    try std.testing.expect(register.get_af() == 0);
    register.a = 10;
    try std.testing.expect(register.get_af() == 2560);

    var f: FlagRegister = @bitCast(register.f);
    try std.testing.expect(f.zero == false);
    try std.testing.expect(f.carry == false);
    try std.testing.expect(f.subtract == false);
    try std.testing.expect(f.half_carry == false);

    f.zero = true;
    register.f = @bitCast(f);
    try std.testing.expectEqual(register.f, 128);
}

test "basic cpu add functionality" {
    var cpu = try CreateCpu();
    var f: *FlagRegister = @ptrCast(&cpu.registers.f);

    // Test ADD;
    cpu.registers.a = 10;
    cpu.registers.b = 5;
    try cpu.execute(Instruction.ADD, RegisterNames.B, 0);
    try std.testing.expectEqual(15, cpu.registers.a);
    try std.testing.expectEqual(false, f.carry);

    cpu.registers.a = 0xFF;
    cpu.registers.b = 1;
    try cpu.execute(Instruction.ADD, RegisterNames.B, 0);
    try std.testing.expectEqual(0, cpu.registers.a);
    try std.testing.expectEqual(true, f.carry);

    // Test ADDHL;
    cpu.registers.set_hl(0x1234);
    cpu.registers.set_de(0x0011);
    try cpu.execute(Instruction.ADDHL, RegisterNames.DE, 0);
    try std.testing.expectEqual(0x1245, cpu.registers.get_hl());
    try std.testing.expectEqual(false, f.carry);

    // Test addition with carry (simulate overflow)
    cpu.registers.set_hl(0xFFFF);
    cpu.registers.set_de(0x0001);
    try cpu.execute(Instruction.ADDHL, RegisterNames.DE, 0);
    try std.testing.expectEqual(0x0000, cpu.registers.get_hl()); // Overflow
    try std.testing.expectEqual(true, f.carry);

    cpu.registers.a = 0;
    f.carry = true;
    try cpu.execute(Instruction.ADC, RegisterNames.C, 0);
    try std.testing.expectEqual(1, cpu.registers.a);
    try std.testing.expectEqual(false, f.carry);

    // Test ADC with carry flag set and actual carry
    cpu.registers.a = 0xFF;
    f.carry = true;
    cpu.registers.c = 0;
    try cpu.execute(Instruction.ADC, RegisterNames.C, 0);
    try std.testing.expectEqual(0, cpu.registers.a);
    try std.testing.expectEqual(true, f.carry);
}

test "basic cpu sub functionality" {
    var cpu = try CreateCpu();
    var f: *FlagRegister = @ptrCast(&cpu.registers.f);

    // Test SUB
    cpu.registers.a = 10;
    cpu.registers.b = 5;
    try cpu.execute(Instruction.SUB, RegisterNames.B, 0);
    try std.testing.expectEqual(5, cpu.registers.a);
    try std.testing.expectEqual(false, f.carry);

    // Test subtraction with borrow
    cpu.registers.a = 5;
    cpu.registers.b = 10;
    try cpu.execute(Instruction.SUB, RegisterNames.B, 0);
    try std.testing.expectEqual(251, cpu.registers.a); // Underflow
    try std.testing.expectEqual(true, f.carry);

    // Test SBC;
    cpu.registers.a = 5;
    f.carry = true;
    cpu.registers.b = 3;
    try cpu.execute(Instruction.SBC, RegisterNames.B, 0);
    try std.testing.expectEqual(1, cpu.registers.a);
    try std.testing.expectEqual(false, f.carry);

    // Test SBC with carry flag set and actual borrow
    cpu.registers.a = 0;
    f.carry = true;
    cpu.registers.b = 0;
    try cpu.execute(Instruction.SBC, RegisterNames.B, 0);
    try std.testing.expectEqual(255, cpu.registers.a); // Borrows from previous carry
    try std.testing.expectEqual(true, f.carry);
}

test "basic cpu boolean functionality" {
    var cpu = try CreateCpu();
    const f: *FlagRegister = @ptrCast(&cpu.registers.f);

    cpu.registers.a = 0xF;
    cpu.registers.b = 0x3;
    try cpu.execute(Instruction.AND, RegisterNames.B, 0);
    try std.testing.expectEqual(0x3, cpu.registers.a);
    try std.testing.expectEqual(false, f.carry);

    cpu.registers.a = 0xF;
    cpu.registers.b = 0x3;
    try cpu.execute(Instruction.OR, RegisterNames.B, 0);
    try std.testing.expectEqual(0xF, cpu.registers.a);
    try std.testing.expectEqual(false, f.carry);

    cpu.registers.a = 5;
    cpu.registers.b = 3;
    try cpu.execute(Instruction.XOR, RegisterNames.B, 0);
    try std.testing.expectEqual(6, cpu.registers.a);
    try std.testing.expectEqual(false, f.carry);
}

test "INC, DEC, RRA, RLA instructions" {
    var cpu = try CreateCpu();
    const f: *FlagRegister = @ptrCast(&cpu.registers.f);

    // INC tests;

    cpu.registers.a = 0xFF;
    try cpu.execute(Instruction.INC, RegisterNames.A, 0);
    try std.testing.expectEqual(0, cpu.registers.a);
    try std.testing.expectEqual(true, f.zero);
    try std.testing.expectEqual(true, f.carry);
    try std.testing.expectEqual(true, f.half_carry);

    cpu.registers.a = 0x0F;
    try cpu.execute(Instruction.INC, RegisterNames.A, 0);
    try std.testing.expectEqual(0x10, cpu.registers.a);
    try std.testing.expectEqual(false, f.zero);
    try std.testing.expectEqual(false, f.carry);
    try std.testing.expectEqual(true, f.half_carry);

    // DEC tests;
    cpu.registers.a = 0x01;
    try cpu.execute(Instruction.DEC, RegisterNames.A, 0);
    try std.testing.expectEqual(0x00, cpu.registers.a);
    try std.testing.expectEqual(true, f.zero);
    try std.testing.expectEqual(false, f.carry);
    try std.testing.expectEqual(false, f.half_carry);

    cpu.registers.a = 0x10;
    try cpu.execute(Instruction.DEC, RegisterNames.A, 0);
    try std.testing.expectEqual(0x0F, cpu.registers.a);
    try std.testing.expectEqual(false, f.zero);
    try std.testing.expectEqual(false, f.carry);
    try std.testing.expectEqual(true, f.half_carry);

    // RRA tests
    cpu.registers.a = 0x81;
    f.carry = true;
    try cpu.execute(Instruction.RRA, RegisterNames.A, 0);
    try std.testing.expectEqual(0xC0, cpu.registers.a);
    try std.testing.expectEqual(false, f.zero);
    try std.testing.expectEqual(true, f.carry);
    try std.testing.expectEqual(false, f.half_carry);

    // RLA tests
    cpu.registers.a = 0x40;
    f.carry = true;
    try cpu.execute(Instruction.RLA, RegisterNames.A, 0);
    try std.testing.expectEqual(0x81, cpu.registers.a);
    try std.testing.expectEqual(false, f.zero);
    try std.testing.expectEqual(false, f.carry);
    try std.testing.expectEqual(false, f.half_carry);
}
