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
        if (instruction.mode == game_instructions.AddressMode.PTR_R) {
            const addr_hi: u16 = try cpu.emu.memory_bus.?.*.read(cpu.registers.pc);
            cpu.emu.cycle(1);
            const addr_lo: u16 = try cpu.emu.memory_bus.?.*.read(cpu.registers.pc + 1);
            cpu.emu.cycle(1);
            const address: u16 = addr_lo | (addr_hi << 8);
            cpu.registers.pc += 2;

            if (try game_instructions.reg_is_u8(instruction.reg_2)) {
                try write_u8(cpu, address, @truncate(cpu.fetched_data));
            } else {
                try write_u16(cpu, address, cpu.fetched_data);
            }
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

fn proc_nop(cpu: *game_cpu.CPU) !void {
    cpu.emu.cycle(1);
}

fn proc_call(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    if (!try check_cond(cpu, instruction)) {
        std.debug.print("Did not match cond\n", .{});
        return;
    }
}

pub fn proc(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    switch (instruction.in_type) {
        game_instructions.InstructionType.NOP => try proc_nop(cpu),
        game_instructions.InstructionType.JP => try proc_jp(cpu, instruction),
        game_instructions.InstructionType.DI => try proc_di(cpu),
        game_instructions.InstructionType.LD => try proc_ld(cpu, instruction),
        game_instructions.InstructionType.CALL => try proc_call(cpu, instruction),
        else => {
            std.log.debug("Proc not implemented: {s}", .{@tagName(instruction.in_type)});
            return game_errors.EmuErrors.ProcNotImplemented;
        },
    }
}
