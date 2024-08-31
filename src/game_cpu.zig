const std = @import("std");
const game_allocator = @import("game_allocator.zig");
const game_instructions = @import("game_instructions.zig");
const game_emu = @import("game_emu.zig");
const game_errors = @import("game_errors.zig");
const game_proc = @import("game_proc.zig");

//16-bit        Hi      Lo      Name/Function
//AF    A       -       Accumulator & Flags
//BC    B       C       BC
//DE    D       E       DE
//HL    H       L       HL
//SP    -       -       Stack Pointer
//PC    -       -       Program Counter/Pointer
//
//Bit   Name    Explanation
//7     z       Zero flag
//6     n       Subtraction flag (BCD)
//5     h       Half Carry flag (BCD)
//4     c       Carry flag

const FlagsRegister = packed struct(u8) {
    _: u4,
    c: u1, // carry
    h: u1, // half-carry
    n: u1, // subtraction flag
    z: u1, // zero flag
};

const Registers = packed struct { f: u8, a: u8, c: u8, b: u8, e: u8, d: u8, l: u8, h: u8, sp: u16, pc: u16 };
const RegistersU16 = packed struct {
    AF: u16,
    BC: u16,
    DE: u16,
    HL: u16,
};

pub const CPU = struct {
    allocator: std.mem.Allocator,
    emu: *game_emu.Emu,
    registers: *Registers,
    registers_u16: *RegistersU16,
    flag_register: *FlagsRegister,
    test_file_log: std.fs.File,

    current_opcode: u8,
    current_instruction: ?game_instructions.Instruction,
    opcode_instruction_map: std.AutoHashMap(u8, game_instructions.Instruction),
    prefixed_opcode_instruction_map: std.AutoHashMap(u8, game_instructions.Instruction),
    fetched_data: u16,

    enabling_ime: bool,
    interrupt_master_enable: bool,
    ie_register: u8,
    int_flags: u8,

    halted: bool,
    stepping: bool,

    pub fn init(emu: *game_emu.Emu) !*CPU {
        const allocator = game_allocator.GetAllocator();
        const cpu = try allocator.create(CPU);

        cpu.emu = emu;
        cpu.allocator = allocator;
        cpu.test_file_log = try std.fs.cwd().createFile(
            "log-file.txt",
            .{ .read = true },
        );

        cpu.fetched_data = 0;
        cpu.enabling_ime = false;
        cpu.interrupt_master_enable = false;
        cpu.ie_register = 0;
        cpu.int_flags = 0;

        cpu.halted = false;
        cpu.stepping = false;

        cpu.registers = try allocator.create(Registers);
        cpu.registers.a = 0;
        cpu.registers.f = 0;
        cpu.registers.b = 0;
        cpu.registers.c = 0;
        cpu.registers.d = 0;
        cpu.registers.e = 0;
        cpu.registers.h = 0;
        cpu.registers.l = 0;
        cpu.registers.sp = 0;
        cpu.registers.pc = 0;

        cpu.registers_u16 = @ptrCast(cpu.registers);
        cpu.flag_register = @ptrCast(&cpu.registers.f);

        cpu.current_opcode = 0;
        cpu.current_instruction = null;
        cpu.opcode_instruction_map = try game_instructions.GetInstructionMap();
        cpu.prefixed_opcode_instruction_map = try game_instructions.GetPrefixedInstructionMap();

        return cpu;
    }

    pub fn step(self: *CPU) !bool {
        // TESTS
        const test_log: []const u8 = try std.fmt.allocPrint(
            self.allocator,
            "A:{X:0>2} F:{X:0>2} B:{X:0>2} C:{X:0>2} D:{X:0>2} E:{X:0>2} H:{X:0>2} L:{X:0>2} SP:{X:0>4} PC:{X:0>4} PCMEM:{X:0>2},{X:0>2},{X:0>2},{X:0>2}\n",
            .{
                self.registers.a,
                self.registers.f,
                self.registers.b,
                self.registers.c,
                self.registers.d,
                self.registers.e,
                self.registers.h,
                self.registers.l,
                self.registers.sp,
                self.registers.pc,
                try self.emu.memory_bus.?.read(self.registers.pc + 0),
                try self.emu.memory_bus.?.read(self.registers.pc + 1),
                try self.emu.memory_bus.?.read(self.registers.pc + 2),
                try self.emu.memory_bus.?.read(self.registers.pc + 3),
            },
        );

        _ = try self.test_file_log.write(test_log);
        // DONE TESTING LOG

        const pc = self.registers.pc;
        const previous_cycle_num = self.emu.cycle_num;
        var new_pc: u16 = 0;
        if (!self.halted) {
            try self.fetch_instruction();
            try self.fetch_data();
            new_pc = self.registers.pc;
            std.debug.print("{d} - {X:0>4}:  {s: >4} ({X:0>2} {X:0>2} {X:0>2}) SP: {X:0>4} A: {X:0>2} BC: {X:0>4} DE: {X:0>4} HL: {X:0>4} F: {any}\n", .{
                self.emu.ticks,
                pc, // Program Counter we started with
                @tagName(self.current_instruction.?.in_type),
                try self.emu.memory_bus.?.*.read(pc),
                try self.emu.memory_bus.?.*.read(pc + 1),
                try self.emu.memory_bus.?.*.read(pc + 2),
                self.registers.sp,
                self.registers.a,
                self.registers_u16.BC,
                self.registers_u16.DE,
                self.registers_u16.HL,
                self.flag_register,
            });

            try self.emu.dbg.?.update(self.emu.memory_bus.?);
            self.emu.dbg.?.print();

            try self.execute();
        } else {
            // Halted
            self.emu.cycle(1);
            if (self.int_flags != 0) {
                self.halted = true;
            }
        }

        if (self.interrupt_master_enable) {
            try self.handle_interrupts();
            self.enabling_ime = false;
        }

        if (self.enabling_ime) {
            self.interrupt_master_enable = true;
        }

        const num_cycles = 4 * (self.emu.cycle_num - previous_cycle_num);
        const num_bytes = new_pc - pc;
        std.debug.print("\t Num Bytes: {d} Num Cycles: {d}\n\n", .{ num_bytes, num_cycles });

        return true;
    }

    fn interrupt_handle(self: *CPU, address: u16) !void {
        try self.stack_push_u16(self.registers.pc);
        self.registers.pc = address;
    }

    fn interrupt_check(self: *CPU, address: u16, interrupt_check_val: u8) !bool {
        const int_flag = self.int_flags & interrupt_check_val;
        const ie_register = self.ie_register & interrupt_check_val;

        if ((int_flag == interrupt_check_val) and (ie_register == interrupt_check_val)) {
            try self.interrupt_handle(address);
            self.int_flags = self.int_flags & (~interrupt_check_val); //reset the interrupt flag at the check value;
            self.halted = false;
            self.interrupt_master_enable = false;
            return true;
        }

        return false;
    }

    fn handle_interrupts(self: *CPU) !void {
        const one: u8 = 1;
        if (try self.interrupt_check(0x40, one)) {
            //VBLANK

        } else if (try self.interrupt_check(0x48, one << 1)) {
            //LCD

        } else if (try self.interrupt_check(0x50, one << 2)) {
            //TIMER

        } else if (try self.interrupt_check(0x58, one << 3)) {
            //SERIAL

        } else if (try self.interrupt_check(0x60, one << 4)) {
            //JoyPad
        }
    }

    fn execute(self: *CPU) !void {
        try game_proc.proc(self, self.current_instruction.?);
        return;
    }

    fn fetch_instruction(self: *CPU) !void {
        self.current_opcode = try self.emu.memory_bus.?.*.read(self.registers.pc);
        self.registers.pc += 1;

        // fetch the instruction by the op code
        const current_instruction = self.opcode_instruction_map.get(self.current_opcode);
        if (current_instruction) |found| {
            self.current_instruction = found;
        } else {
            std.log.debug("Op code not implemented in instruction map: 0x{X:0>2}", .{self.current_opcode});
            return game_errors.EmuErrors.OpNotImplementedError;
        }
    }

    pub fn read_reg(self: *CPU, reg: game_instructions.RegisterType) !u16 {
        return switch (reg) {
            game_instructions.RegisterType.NONE => return game_errors.EmuErrors.NotImplementedError,
            game_instructions.RegisterType.A => self.registers.a,
            game_instructions.RegisterType.B => self.registers.b,
            game_instructions.RegisterType.C => self.registers.c,
            game_instructions.RegisterType.D => self.registers.d,
            game_instructions.RegisterType.E => self.registers.e,
            game_instructions.RegisterType.F => self.registers.f,
            game_instructions.RegisterType.H => self.registers.h,
            game_instructions.RegisterType.L => self.registers.l,
            game_instructions.RegisterType.AF => self.registers_u16.AF,
            game_instructions.RegisterType.BC => self.registers_u16.BC,
            game_instructions.RegisterType.DE => self.registers_u16.DE,
            game_instructions.RegisterType.HL => self.registers_u16.HL,
            game_instructions.RegisterType.PC => self.registers.pc,
            game_instructions.RegisterType.SP => self.registers.sp,
        };
    }

    pub fn write_reg(self: *CPU, reg: game_instructions.RegisterType, value: u16) !void {
        switch (reg) {
            game_instructions.RegisterType.NONE => return game_errors.EmuErrors.NotImplementedError,
            game_instructions.RegisterType.A => self.registers.a = @truncate(value),
            game_instructions.RegisterType.B => self.registers.b = @truncate(value),
            game_instructions.RegisterType.C => self.registers.c = @truncate(value),
            game_instructions.RegisterType.D => self.registers.d = @truncate(value),
            game_instructions.RegisterType.E => self.registers.e = @truncate(value),
            game_instructions.RegisterType.F => self.registers.f = @truncate(value),
            game_instructions.RegisterType.H => self.registers.h = @truncate(value),
            game_instructions.RegisterType.L => self.registers.l = @truncate(value),
            game_instructions.RegisterType.AF => {
                //self.registers.a = @truncate(value >> 4);
                //self.registers.f = @truncate(value);
                self.registers_u16.AF = value;
            },
            game_instructions.RegisterType.BC => {
                //self.registers.b = @truncate(value >> 4);
                //self.registers.c = @truncate(value);
                self.registers_u16.BC = value;
            },
            game_instructions.RegisterType.DE => {
                //self.registers.d = @truncate(value >> 4);
                //self.registers.e = @truncate(value);
                self.registers_u16.DE = value;
            },
            game_instructions.RegisterType.HL => {
                //self.registers.h = @truncate(value >> 4);
                //self.registers.l = @truncate(value);
                self.registers_u16.HL = value;
            },
            game_instructions.RegisterType.PC => self.registers.pc = value,
            game_instructions.RegisterType.SP => self.registers.sp = value,
        }
        return;
    }

    fn fetch_data(self: *CPU) !void {
        switch (self.current_instruction.?.mode) {
            game_instructions.AddressMode.IMP => {
                return;
            },
            game_instructions.AddressMode.R => {
                self.fetched_data = try self.read_reg(self.current_instruction.?.reg_1);
                return;
            },
            game_instructions.AddressMode.PTR => {
                const address: u16 = try self.read_reg(self.current_instruction.?.reg_1);
                self.fetched_data = try self.emu.memory_bus.?.read(address);
                self.emu.cycle(1);
                return;
            },
            game_instructions.AddressMode.R_N8 => {
                self.fetched_data = try self.emu.memory_bus.?.*.read(self.registers.pc);
                self.emu.cycle(1);
                self.registers.pc += 1;
                return;
            },
            game_instructions.AddressMode.R_N16 => {
                const lo: u16 = try self.emu.memory_bus.?.*.read(self.registers.pc);
                self.emu.cycle(1);
                const hi: u16 = try self.emu.memory_bus.?.*.read(self.registers.pc + 1);
                self.emu.cycle(1);
                self.fetched_data = lo | (hi << 8);
                self.registers.pc += 2;
                return;
            },
            game_instructions.AddressMode.N8 => {
                const value: u8 = try self.emu.memory_bus.?.*.read(self.registers.pc);
                self.fetched_data = value;
                self.emu.cycle(1);
                self.registers.pc += 1;
                return;
            },
            game_instructions.AddressMode.N16 => {
                const lo: u16 = try self.emu.memory_bus.?.*.read(self.registers.pc);
                self.emu.cycle(1);
                const hi: u16 = try self.emu.memory_bus.?.*.read(self.registers.pc + 1);
                self.emu.cycle(1);
                self.fetched_data = lo | (hi << 8);
                self.registers.pc += 2;
                return;
            },
            game_instructions.AddressMode.PTR_R => {
                self.fetched_data = try self.read_reg(self.current_instruction.?.reg_2);
                self.emu.cycle(1);
                return;
            },
            game_instructions.AddressMode.R_PTR => {
                const addr: u16 = try self.read_reg(self.current_instruction.?.reg_2);
                self.fetched_data = try self.emu.memory_bus.?.*.read(addr);
                self.emu.cycle(1);
                return;
            },
            game_instructions.AddressMode.A8_R => {
                self.fetched_data = try self.read_reg(self.current_instruction.?.reg_2);
                self.emu.cycle(1);
                return;
            },
            game_instructions.AddressMode.R_A8 => {
                const lo: u16 = try self.emu.memory_bus.?.*.read(self.registers.pc);
                self.emu.cycle(1);
                const addr: u16 = lo | 0xFF00;
                self.fetched_data = try self.emu.memory_bus.?.*.read(addr);
                self.emu.cycle(1);
                self.registers.pc += 1;
                return;
            },
            game_instructions.AddressMode.A16_R => {
                self.fetched_data = try self.read_reg(self.current_instruction.?.reg_2);
                self.emu.cycle(1);
                return;
            },
            game_instructions.AddressMode.R_A16 => {
                const lo: u8 = try self.emu.memory_bus.?.*.read(self.registers.pc);
                const hi: u8 = try self.emu.memory_bus.?.*.read(self.registers.pc + 1);
                self.registers.pc += 2;
                self.emu.cycle(2);
                const addr: u16 = @as(u16, lo) | (@as(u16, hi) << 8);
                self.fetched_data = try self.emu.memory_bus.?.*.read(addr);
                return;
            },
            game_instructions.AddressMode.R_R => {
                self.fetched_data = try self.read_reg(self.current_instruction.?.reg_2);
                self.emu.cycle(1);
                return;
            },
            else => {
                std.log.debug("Op code: 0x{X:0>2}\n", .{self.current_opcode});
                std.log.debug("Instruction: {any}\n", .{self.current_instruction});
                std.log.debug("Fetch not implemented for address mode: {s}", .{@tagName(self.current_instruction.?.mode)});
                return game_errors.EmuErrors.OpNotImplementedError;
            },
        }
    }

    pub fn stack_push_u8(self: *CPU, value: u8) !void {
        self.registers.sp -= 1;
        try self.emu.memory_bus.?.write(self.registers.sp, value);
    }

    pub fn stack_push_u16(self: *CPU, value: u16) !void {
        try self.stack_push_u8(@truncate((value >> 8) & 0x00FF)); //HI
        try self.stack_push_u8(@truncate(value & 0x00FF)); // LO
    }

    pub fn stack_pop_u8(self: *CPU) !u8 {
        const value: u8 = try self.emu.memory_bus.?.read(self.registers.sp);
        self.registers.sp += 1;
        return value;
    }

    pub fn stack_pop_u16(self: *CPU) !u16 {
        const lo: u16 = try self.stack_pop_u8();
        const hi: u16 = try self.stack_pop_u8();
        const value: u16 = lo | (hi << 8);
        return value;
    }

    pub fn destroy(self: *CPU) void {
        self.test_file_log.close();
        self.opcode_instruction_map.deinit();
        self.allocator.destroy(self.registers);
        self.allocator.destroy(self);
    }
};

// TESTS

test "Test fetch instruction" {
    const emu = try game_emu.Emu.init();
    defer emu.destroy();
    try emu.prep_emu("./roms/dmg-acid2.gb");
    var cpu = emu.cpu.?.*;
    try cpu.fetch_instruction();
    try std.testing.expect(emu.cart.?.*.data[0x0100] == cpu.current_opcode);
}

test "Test cpu" {
    const emu = try game_emu.Emu.init();
    defer emu.destroy();
    try emu.prep_emu("./roms/dmg-acid2.gb");
    const cpu = emu.cpu.?.*;

    cpu.flag_register.z = 1;
    cpu.flag_register.n = 1;
    cpu.flag_register.h = 1;
    cpu.flag_register.c = 1;

    cpu.registers.a = 0xFF;

    try std.testing.expectEqual(0xF0, cpu.registers.f);
    try std.testing.expectEqual(0xFFF0, cpu.registers_u16.AF);
}

test "Test flag register struct" {
    var f: u8 = 0xD0;
    var flag: *FlagsRegister = @ptrCast(&f);
    flag.h = 1;
    try std.testing.expectEqual(0xF0, f);
}

test "Test lo and hi" {
    const emu = try game_emu.Emu.init();
    defer emu.destroy();
    try emu.prep_emu("./roms/dmg-acid2.gb");
    const cpu = emu.cpu.?.*;

    //std.debug.print("AF: 0x{X:0>4}\n", .{cpu.registers_u16.AF});

    const lo: u8 = @truncate(cpu.registers_u16.AF);
    const hi: u8 = @truncate(cpu.registers_u16.AF >> 8);

    try std.testing.expectEqual(0x01, hi);
    try std.testing.expectEqual(0xB0, lo);

    //std.debug.print("LO: 0x{X:0>2}\n", .{lo});
    //std.debug.print("HI: 0x{X:0>2}\n", .{hi});

    //std.debug.print("AF Bin: 0b{b:0>16}\n", .{cpu.registers_u16.AF});
    //std.debug.print("lo Bin: 0b{b:0>8}\n", .{lo});
    //std.debug.print("hi Bin: 0b{b:0>8}\n", .{hi});
}

test "Test registers struct" {
    const emu = try game_emu.Emu.init();
    defer emu.destroy();
    try emu.prep_emu("./roms/dmg-acid2.gb");
    const cpu = emu.cpu.?.*;

    const lo: u16 = 0x00;
    const hi: u16 = 0x40;
    const value = (hi << 8) | lo;
    cpu.registers_u16.HL = value;

    try std.testing.expect(cpu.registers_u16.HL == 0x4000);
    //std.debug.print("{X:0>4}\n", .{cpu.registers_u16.HL});
    //std.debug.print("H: {X:0>2} L: {X:0>2}\n", .{ cpu.registers.h, cpu.registers.l });
}
