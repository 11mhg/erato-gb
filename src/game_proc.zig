const std = @import("std");
const game_cpu = @import("game_cpu.zig");
const game_errors = @import("game_errors.zig");
const game_instructions = @import("game_instructions.zig");

fn check_cond(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !bool {
    const flags = cpu.flag_register;

    switch (instruction.cond) {
        game_instructions.ConditionType.NONE => return true,
        game_instructions.ConditionType.NZ => return flags.z != 0,
        game_instructions.ConditionType.Z => return flags.z == 0,
        game_instructions.ConditionType.NC => return flags.c != 0,
        game_instructions.ConditionType.C => return flags.c == 0,
        game_instructions.ConditionType.NH => return flags.h != 0,
        game_instructions.ConditionType.H => return flags.h == 0,
    }
}

fn proc_di(cpu: *game_cpu.CPU) !void {
    cpu.interrupt_master_enable = false;
    cpu.emu.cycle(1);
    return;
}

fn proc_jp(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    if (!try check_cond(cpu, instruction)) {
        std.debug.print("Did not match cond\n", .{});
        return;
    }
    cpu.registers.pc = cpu.fetched_data;
    cpu.emu.cycle(1);
}

fn proc_ld(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    if (instruction.reg_1 == game_instructions.RegisterType.NONE) {
        if (instruction.mode == game_instructions.AddressMode.N16_R) {
            const address: u16 = cpu.fetched_data;
            std.debug.print("LD N16 A: 0x{X:0>4}\n", .{address});
            try write_to_addr(cpu, instruction.reg_2, address);
            return;
        }
    } else {
        const value: u16 = cpu.fetched_data;
        try cpu.write_reg(instruction.reg_1, value);
        cpu.emu.cycle(1);
        return;
    }

    return game_errors.EmuErrors.ProcNotImplemented;
}

fn write_u8(cpu: *game_cpu.CPU, address: u16, value: u8) !void {
    try cpu.emu.memory_bus.?.*.write(address, value);
}

fn write_u16(cpu: *game_cpu.CPU, address: u16, value: u16) !void {
    try cpu.emu.memory_bus.?.*.write(address, @truncate(value));
    try cpu.emu.memory_bus.?.*.write(address + 1, @truncate(value >> 8));
}

fn write_to_addr(cpu: *game_cpu.CPU, reg: game_instructions.RegisterType, address: u16) !void {
    switch (reg) {
        game_instructions.RegisterType.A => try write_u8(cpu, address, cpu.registers.a),
        game_instructions.RegisterType.B => try write_u8(cpu, address, cpu.registers.b),
        game_instructions.RegisterType.C => try write_u8(cpu, address, cpu.registers.c),
        game_instructions.RegisterType.D => try write_u8(cpu, address, cpu.registers.d),
        game_instructions.RegisterType.E => try write_u8(cpu, address, cpu.registers.e),
        game_instructions.RegisterType.F => try write_u8(cpu, address, cpu.registers.f),
        game_instructions.RegisterType.H => try write_u8(cpu, address, cpu.registers.h),
        game_instructions.RegisterType.L => try write_u8(cpu, address, cpu.registers.l),
        game_instructions.RegisterType.AF => try write_u16(cpu, address, cpu.registers_u16.AF),
        game_instructions.RegisterType.BC => try write_u16(cpu, address, cpu.registers_u16.BC),
        game_instructions.RegisterType.DE => try write_u16(cpu, address, cpu.registers_u16.DE),
        game_instructions.RegisterType.HL => try write_u16(cpu, address, cpu.registers_u16.HL),
        game_instructions.RegisterType.SP => try write_u16(cpu, address, cpu.registers.sp),
        game_instructions.RegisterType.PC => try write_u16(cpu, address, cpu.registers.pc),
        game_instructions.RegisterType.NONE => return game_errors.EmuErrors.NotImplementedError,
    }
}

fn proc_nop(cpu: *game_cpu.CPU) !void {
    cpu.emu.cycle(1);
}

pub fn proc(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    switch (instruction.in_type) {
        game_instructions.InstructionType.NOP => try proc_nop(cpu),
        game_instructions.InstructionType.JP => try proc_jp(cpu, instruction),
        game_instructions.InstructionType.DI => try proc_di(cpu),
        game_instructions.InstructionType.LD => try proc_ld(cpu, instruction),
        else => {
            std.log.debug("Proc not implemented: {s}", .{@tagName(instruction.in_type)});
            return game_errors.EmuErrors.ProcNotImplemented;
        },
    }
}
