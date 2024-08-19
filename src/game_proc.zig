const std = @import("std");
const game_cpu = @import("game_cpu.zig");
const game_errors = @import("game_errors.zig");
const game_instructions = @import("game_instructions.zig");

fn sub_with_carry_check_u16(left: u16, right: u16) std.meta.Tuple(&.{ u16, u1, u1 }) {
    const overflow_result = @subWithOverflow(left, right);
    const result = overflow_result[0];
    const overflow = overflow_result[1];
    const half_carry: u1 = @intFromBool(@subWithOverflow(left & 0x00FF, right & 0x00FF)[0] & 0x0100 == 0x0100);
    return .{ result, overflow, half_carry };
}

fn sub_with_carry_check_u8(left: u8, right: u8) std.meta.Tuple(&.{ u8, u1, u1 }) {
    const overflow_result = @subWithOverflow(left, right);
    const result = overflow_result[0];
    const overflow = overflow_result[1];
    const half_carry: u1 = @intFromBool(@subWithOverflow(left & 0x0F, right & 0x0F)[0] & 0x10 == 0x10);
    return .{ result, overflow, half_carry };
}

fn add_with_carry_check_u8(left: u8, right: u8) std.meta.Tuple(&.{ u8, u1, u1 }) {
    const overflow_result = @addWithOverflow(left, right);
    const result = overflow_result[0];
    const overflow = overflow_result[1];
    const half_carry: u1 = @intFromBool(@addWithOverflow(left & 0x0F, right & 0x0F)[0] & 0x10 == 0x10);
    return .{ result, overflow, half_carry };
}

fn add_with_carry_check_u16(left: u16, right: u16) std.meta.Tuple(&.{ u16, u1, u1 }) {
    const overflow_result = @addWithOverflow(left, right);
    const result = overflow_result[0];
    const overflow = overflow_result[1];
    const half_carry: u1 = @intFromBool(@addWithOverflow(left & 0x00FF, right & 0x00FF)[0] & 0x0100 == 0x0100);
    return .{ result, overflow, half_carry };
}

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
    if (instruction.in_type == game_instructions.InstructionType.LDI or instruction.in_type == game_instructions.InstructionType.LDD) {
        // increment HL
        var reg_to_choose = instruction.reg_1;
        if (instruction.mode == game_instructions.AddressMode.R_PTR) {
            reg_to_choose = instruction.reg_2;
        }
        var value = try cpu.read_reg(reg_to_choose);
        if (instruction.in_type == game_instructions.InstructionType.LDI) {
            value += 1;
        } else {
            value -= 1;
        }
        try cpu.write_reg(reg_to_choose, value);
    }

    switch (instruction.mode) {
        game_instructions.AddressMode.R_PTR, game_instructions.AddressMode.R_N8, game_instructions.AddressMode.R_N16, game_instructions.AddressMode.R_R => {
            const value: u16 = cpu.fetched_data;
            try cpu.write_reg(instruction.reg_1, value);
            cpu.emu.cycle(1);
            return;
        },
        game_instructions.AddressMode.A16_R => {
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
        },
        game_instructions.AddressMode.PTR_R => {
            const addr: u16 = try cpu.read_reg(instruction.reg_1);

            if (try game_instructions.reg_is_u8(instruction.reg_2)) {
                try write_u8(cpu, addr, @truncate(cpu.fetched_data));
            } else {
                try write_u16(cpu, addr, cpu.fetched_data);
            }
            return;
        },
        else => {
            std.debug.print("LD with address mode {s} not implemented yet", .{@tagName(instruction.mode)});
        },
    }
    return game_errors.EmuErrors.ProcNotImplemented;
}

fn proc_ldh(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    if (instruction.mode == game_instructions.AddressMode.A8_R) {
        const addr_lo: u16 = try cpu.emu.memory_bus.?.*.read(cpu.registers.pc);
        const address: u16 = addr_lo | 0xFF00;
        cpu.emu.cycle(1);
        cpu.registers.pc += 1;
        try write_u8(cpu, address, @truncate(cpu.fetched_data));
        cpu.emu.cycle(1);
        return;
    }

    return game_errors.EmuErrors.ProcNotImplemented;
}

fn write_u8(cpu: *game_cpu.CPU, address: u16, value: u8) !void {
    try cpu.emu.memory_bus.?.*.write(address, value);
}

fn write_u16(cpu: *game_cpu.CPU, address: u16, value: u16) !void {
    const lo: u8 = @truncate(value);
    const hi: u8 = @truncate(value >> 8);
    try cpu.emu.memory_bus.?.*.write(address, lo);
    try cpu.emu.memory_bus.?.*.write(address + 1, hi);
}

fn proc_nop(cpu: *game_cpu.CPU) !void {
    cpu.emu.cycle(1);
}

fn proc_call(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    if (!try check_cond(cpu, instruction)) {
        std.debug.print("Did not match cond\n", .{});
        return;
    }

    return game_errors.EmuErrors.ProcNotImplemented;
}

fn proc_xor(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    if (instruction.reg_1 != game_instructions.RegisterType.NONE) {
        const left = try cpu.read_reg(instruction.reg_1);
        const right = cpu.fetched_data;
        const result = left ^ right;

        try cpu.write_reg(instruction.reg_1, result);
        cpu.flag_register.z = @intFromBool(result == 0);
        cpu.flag_register.n = 0;
        cpu.flag_register.h = 0;
        cpu.flag_register.c = 0;

        return;
    }
}

fn proc_dec(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    const value: u8 = @truncate(cpu.fetched_data);
    const overflow_results = sub_with_carry_check_u8(value, 1);
    const addr: u16 = try cpu.read_reg(instruction.reg_1);
    const result: u8 = overflow_results[0];
    const half_carry: u1 = overflow_results[2];

    try write_u8(cpu, addr, result);

    cpu.flag_register.z = @intFromBool(result == 0);
    cpu.flag_register.n = 1;
    cpu.flag_register.h = half_carry;
}

pub fn proc(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    switch (instruction.in_type) {
        game_instructions.InstructionType.NOP => try proc_nop(cpu),
        game_instructions.InstructionType.JP => try proc_jp(cpu, instruction),
        game_instructions.InstructionType.DI => try proc_di(cpu),
        game_instructions.InstructionType.LDI, game_instructions.InstructionType.LDD, game_instructions.InstructionType.LD => try proc_ld(cpu, instruction),
        game_instructions.InstructionType.LDH => try proc_ldh(cpu, instruction),
        game_instructions.InstructionType.CALL => try proc_call(cpu, instruction),
        game_instructions.InstructionType.XOR => try proc_xor(cpu, instruction),
        game_instructions.InstructionType.DEC => try proc_dec(cpu, instruction),
        else => {
            std.log.debug("Proc not implemented: {s}", .{@tagName(instruction.in_type)});
            return game_errors.EmuErrors.ProcNotImplemented;
        },
    }
}

// tests

test "Test helper functions in proc" {
    const h1 = sub_with_carry_check_u8(12, 15)[2];
    const h2 = sub_with_carry_check_u8(25, 29)[2];
    const h3 = sub_with_carry_check_u8(97, 29)[2];
    const h4 = sub_with_carry_check_u8(15, 12)[2];

    try std.testing.expect(h1 == 1);
    try std.testing.expect(h2 == 1);
    try std.testing.expect(h3 == 1);
    try std.testing.expect(h4 == 0);
}
