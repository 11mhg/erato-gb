const std = @import("std");
const game_cpu = @import("game_cpu.zig");
const game_errors = @import("game_errors.zig");
const game_instructions = @import("game_instructions.zig");

fn sub_with_carry_check_u16(left: u16, right: u16) std.meta.Tuple(&.{ u16, u1, u1 }) {
    const overflow_result = @subWithOverflow(left, right);
    const result = overflow_result[0];
    const overflow = overflow_result[1];
    const half_carry: u1 = @intFromBool(@subWithOverflow(left & 0x0FFF, right & 0x0FFF)[0] & 0x1000 == 0x1000);
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
    const half_carry: u1 = @intFromBool(@addWithOverflow(left & 0x0FFF, right & 0x0FFF)[0] & 0x1000 == 0x1000);
    return .{ result, overflow, half_carry };
}

fn check_cond(cpu: *game_cpu.CPU, cond: game_instructions.ConditionType) !bool {
    const flags = cpu.flag_register;

    switch (cond) {
        game_instructions.ConditionType.NONE => return true,
        game_instructions.ConditionType.NZ => return flags.z == 0,
        game_instructions.ConditionType.Z => return flags.z == 1,
        game_instructions.ConditionType.NC => return flags.c == 0,
        game_instructions.ConditionType.C => return flags.c == 1,
        game_instructions.ConditionType.NH => return flags.h == 0,
        game_instructions.ConditionType.H => return flags.h == 1,
    }
}

fn proc_di(cpu: *game_cpu.CPU) !void {
    cpu.interrupt_master_enable = false;
    try cpu.emu.cycle(1);
    return;
}

fn proc_ei(cpu: *game_cpu.CPU) !void {
    cpu.enabling_ime = true;
    try cpu.emu.cycle(1);
    return;
}

fn proc_jp_impl(cpu: *game_cpu.CPU, cond: game_instructions.ConditionType, addr: u16, push_pc: bool) !void {
    if (try check_cond(cpu, cond)) {
        if (push_pc) {
            try cpu.emu.cycle(2);
            try cpu.stack_push_u16(cpu.registers.pc);
        }
        cpu.registers.pc = addr;
        try cpu.emu.cycle(1);
    }
}

fn proc_jp(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    if (instruction.mode != game_instructions.AddressMode.R) {
        try cpu.emu.cycle(1);
    }
    try proc_jp_impl(cpu, instruction.cond, cpu.fetched_data, false);
}

fn proc_ldi(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    try proc_ld(cpu, instruction);
    // increment HL
    if (instruction.mode != game_instructions.AddressMode.R_PTR and instruction.mode != game_instructions.AddressMode.PTR_R) {
        std.debug.print("Unexpected Address mode in proc_ldi: {s}\n", .{@tagName(instruction.mode)});
        return game_errors.EmuErrors.NotImplementedError;
    }
    var reg_to_choose = instruction.reg_1;
    if (instruction.mode == game_instructions.AddressMode.R_PTR) {
        reg_to_choose = instruction.reg_2;
    }
    const value = @addWithOverflow(try cpu.read_reg(reg_to_choose), 1)[0];
    try cpu.write_reg(reg_to_choose, value);
}

fn proc_ldd(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    try proc_ld(cpu, instruction);
    // increment HL
    if (instruction.mode != game_instructions.AddressMode.R_PTR and instruction.mode != game_instructions.AddressMode.PTR_R) {
        std.debug.print("Unexpected Address mode in proc_ldi: {s}\n", .{@tagName(instruction.mode)});
        return game_errors.EmuErrors.NotImplementedError;
    }
    var reg_to_choose = instruction.reg_1;
    if (instruction.mode == game_instructions.AddressMode.R_PTR) {
        reg_to_choose = instruction.reg_2;
    }
    const value = @subWithOverflow(try cpu.read_reg(reg_to_choose), 1)[0];
    try cpu.write_reg(reg_to_choose, value);
}

fn proc_ld(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    switch (instruction.mode) {
        game_instructions.AddressMode.R_A16, game_instructions.AddressMode.R_N16, game_instructions.AddressMode.R_R => {
            const value: u16 = cpu.fetched_data;
            try cpu.write_reg(instruction.reg_1, value);
            try cpu.emu.cycle(1);
            std.debug.print("Register: {s} Value: {X:0>2}\n", .{ @tagName(instruction.reg_1), @as(u8, @truncate(value)) });
            if (cpu.current_opcode == 0xF9) {
                try cpu.emu.cycle(1);
            }
            return;
        },
        game_instructions.AddressMode.R_N8 => {
            var value: u16 = cpu.fetched_data;
            if (instruction.reg_2 == game_instructions.RegisterType.SP) {
                //bloating up to i32 b/c e8 comes in as i8 and u16
                //can support more numbers than i16
                const e8: i8 = @bitCast(@as(u8, @truncate(cpu.fetched_data)));
                const sub: bool = e8 < 0;
                const sp: u16 = @intCast(cpu.registers.sp);

                const half_carry: u1 = @intFromBool(((sp & 0xF) + (cpu.fetched_data & 0xF)) >= 0x10);
                const overflow: u1 = @intFromBool(((sp & 0xFF) + (cpu.fetched_data & 0xFF)) >= 0x100);

                if (sub) {
                    value = @subWithOverflow(sp, @abs(e8))[0];
                } else {
                    value = @addWithOverflow(sp, @abs(e8))[0];
                }

                std.debug.print("SP: {X:0>4} e8: {d} = {X:0>4}\n", .{ sp, e8, value });

                cpu.flag_register.z = 0;
                cpu.flag_register.n = 0;
                cpu.flag_register.h = half_carry;
                cpu.flag_register.c = overflow;
                try cpu.emu.cycle(1);
            }
            try cpu.write_reg(instruction.reg_1, value);
            try cpu.emu.cycle(1);
            return;
        },
        game_instructions.AddressMode.A16_R => {
            const addr_lo: u16 = try cpu.emu.memory_bus.?.*.read(cpu.registers.pc);
            const addr_hi: u16 = try cpu.emu.memory_bus.?.*.read(cpu.registers.pc + 1);
            const address: u16 = addr_lo | (addr_hi << 8);
            try cpu.emu.cycle(2);
            cpu.registers.pc += 2;

            if (try game_instructions.reg_is_u8(instruction.reg_2)) {
                try write_u8(cpu, address, @truncate(cpu.fetched_data));
            } else {
                try write_u16(cpu, address, cpu.fetched_data);
            }

            if (instruction.reg_2 == game_instructions.RegisterType.SP) {
                try cpu.emu.cycle(1);
            }
            try cpu.emu.cycle(2);
            return;
        },
        game_instructions.AddressMode.R_PTR => {
            var value: u16 = cpu.fetched_data;
            if (instruction.reg_2 == game_instructions.RegisterType.C) {
                const addr_lo: u16 = try cpu.read_reg(instruction.reg_2);
                const addr: u16 = 0xFF00 | addr_lo;
                value = try cpu.emu.memory_bus.?.read(addr);
            }
            try cpu.write_reg(instruction.reg_1, value);
            try cpu.emu.cycle(1);
            return;
        },
        game_instructions.AddressMode.PTR_R => {
            var addr: u16 = try cpu.read_reg(instruction.reg_1);
            if (cpu.current_opcode == 0xE2) {
                // This is a LD [0xFF + C] A
                addr = 0xFF00 | addr;
            }
            try cpu.emu.cycle(2);

            if (try game_instructions.reg_is_u8(instruction.reg_2)) {
                try write_u8(cpu, addr, @truncate(cpu.fetched_data));
            } else {
                try cpu.emu.cycle(1);
                try write_u16(cpu, addr, cpu.fetched_data);
            }
            return;
        },
        game_instructions.AddressMode.PTR_N8 => {
            const addr: u16 = try cpu.read_reg(instruction.reg_1);
            try cpu.emu.cycle(1);

            try write_u8(cpu, addr, @truncate(cpu.fetched_data));
            return;
        },
        else => {
            std.debug.print("LD with address mode {s} not implemented yet", .{@tagName(instruction.mode)});
            std.debug.print("{any}\n", .{instruction});
        },
    }
    std.log.debug("Proc not implemented: {s}", .{@tagName(instruction.in_type)});
    return game_errors.EmuErrors.ProcNotImplemented;
}

fn proc_ldh(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    if (instruction.mode == game_instructions.AddressMode.A8_R) {
        const value: u8 = @truncate(cpu.fetched_data);

        const addr_lo: u8 = try cpu.emu.memory_bus.?.*.read(cpu.registers.pc);
        const address: u16 = 0xFF00 | @as(u16, addr_lo);

        cpu.registers.pc += 1;

        try write_u8(cpu, address, value);
        try cpu.emu.cycle(2);
        return;
    } else if (instruction.mode == game_instructions.AddressMode.R_A8) {
        const value: u16 = cpu.fetched_data;
        const original_address_lo: u16 = try cpu.emu.memory_bus.?.read(cpu.registers.pc - 1);
        const original_address: u16 = 0xFF00 | original_address_lo;
        std.debug.print("address: {X:0>4} value: {X:0>4} register: {s}\n", .{ original_address, value, @tagName(instruction.reg_1) });
        try cpu.write_reg(instruction.reg_1, value);
        try cpu.emu.cycle(1);
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
    try cpu.emu.cycle(1);
}

fn proc_call(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    try cpu.emu.cycle(1);
    try proc_jp_impl(cpu, instruction.cond, cpu.fetched_data, true);
}

fn proc_xor(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    try cpu.emu.cycle(1);
    const right: u8 = @truncate(cpu.fetched_data);
    const left: u8 = @truncate(try cpu.read_reg(instruction.reg_1));
    const result: u8 = left ^ right;

    try cpu.write_reg(instruction.reg_1, result);
    cpu.flag_register.z = @intFromBool(result == 0);
    cpu.flag_register.n = 0;
    cpu.flag_register.h = 0;
    cpu.flag_register.c = 0;
}

fn proc_inc(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    if (try game_instructions.reg_is_u8(instruction.reg_1) or instruction.mode == game_instructions.AddressMode.PTR) {
        //u8
        const value: u8 = @truncate(cpu.fetched_data);
        const overflow_results = add_with_carry_check_u8(value, 1);
        const result: u8 = overflow_results[0];
        const half_carry = overflow_results[2];

        if (instruction.mode == game_instructions.AddressMode.PTR) {
            // PTR result
            try write_u8(cpu, try cpu.read_reg(instruction.reg_1), result);
        } else {
            // Register result
            try cpu.write_reg(instruction.reg_1, result);
        }

        cpu.flag_register.z = @intFromBool(result == 0);
        cpu.flag_register.n = 0;
        cpu.flag_register.h = half_carry;
        try cpu.emu.cycle(1);
    } else {
        //u16
        const value: u16 = cpu.fetched_data;
        const overflow_results = add_with_carry_check_u16(value, 1);
        const result: u16 = overflow_results[0];
        try cpu.write_reg(instruction.reg_1, result);
        try cpu.emu.cycle(2);
    }
}

fn proc_dec(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    if (try game_instructions.reg_is_u8(instruction.reg_1) or instruction.mode == game_instructions.AddressMode.PTR) {
        //u8
        const value: u8 = @truncate(cpu.fetched_data);
        const overflow_results = sub_with_carry_check_u8(value, 1);
        const result: u8 = overflow_results[0];
        const half_carry = overflow_results[2];

        if (instruction.mode == game_instructions.AddressMode.PTR) {
            // PTR result
            try write_u8(cpu, try cpu.read_reg(instruction.reg_1), result);
            try cpu.emu.cycle(1);
        } else {
            // Register result
            try cpu.write_reg(instruction.reg_1, result);
        }

        cpu.flag_register.z = @intFromBool(result == 0);
        cpu.flag_register.n = 1;
        cpu.flag_register.h = half_carry;
        try cpu.emu.cycle(1);
    } else {
        //u16
        const value: u16 = cpu.fetched_data;
        const overflow_results = sub_with_carry_check_u16(value, 1);
        const result: u16 = overflow_results[0];
        try cpu.write_reg(instruction.reg_1, result);
        try cpu.emu.cycle(2);
    }
}

fn proc_push(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    if (try game_instructions.reg_is_u8(instruction.reg_1)) {
        try cpu.stack_push_u8(@truncate(cpu.fetched_data));
    } else {
        try cpu.stack_push_u16(cpu.fetched_data);
        try cpu.emu.cycle(1);
    }
    try cpu.emu.cycle(3);
}

fn proc_pop(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    if (try game_instructions.reg_is_u8(instruction.reg_1)) {
        const value: u16 = try cpu.stack_pop_u8();
        try cpu.write_reg(instruction.reg_1, value);
    } else {
        const value: u16 = try cpu.stack_pop_u16();
        try cpu.write_reg(instruction.reg_1, value);
        try cpu.emu.cycle(1);
    }
    try cpu.emu.cycle(2);
}

fn proc_jr(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    // JR is a relative jump to address given, the offset is relative to the address immediately
    // following the JR instruction.
    var addr: u16 = cpu.registers.pc;
    const offset_raw: u8 = @truncate(cpu.fetched_data);
    const offset: i8 = @bitCast(offset_raw);
    const sub: bool = offset < 0;

    const offset_u16: u16 = @intCast(@abs(offset));

    if (sub) {
        addr -= offset_u16;
    } else {
        addr += offset_u16;
    }

    try cpu.emu.cycle(1);
    try proc_jp_impl(cpu, instruction.cond, addr, false);
}

fn proc_ret(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    try cpu.emu.cycle(1);
    if (instruction.cond != game_instructions.ConditionType.NONE) {
        try cpu.emu.cycle(1);
    }
    if (!try check_cond(cpu, instruction.cond)) {
        return;
    }

    const lo: u16 = try cpu.stack_pop_u8();
    const hi: u16 = try cpu.stack_pop_u8();
    const addr: u16 = lo | (hi << 8);
    try cpu.emu.cycle(2);

    cpu.registers.pc = addr;
    try cpu.emu.cycle(1);
}

fn proc_reti(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    cpu.interrupt_master_enable = true;
    try proc_ret(cpu, instruction);
}

fn proc_rst(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    try proc_jp_impl(cpu, instruction.cond, instruction.param, true);
}

fn proc_add(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    const right: u16 = cpu.fetched_data;
    const left: u16 = try cpu.read_reg(instruction.reg_1);

    if (try game_instructions.reg_is_u8(instruction.reg_1)) {
        try cpu.emu.cycle(1);
        const overflow_result = add_with_carry_check_u8(@truncate(left), @truncate(right));
        const result: u8 = overflow_result[0];
        const carry: u1 = overflow_result[1];
        const half_carry: u1 = overflow_result[2];

        try cpu.write_reg(instruction.reg_1, result);

        cpu.flag_register.z = @intFromBool(result == 0);
        cpu.flag_register.n = 0;
        cpu.flag_register.h = half_carry;
        cpu.flag_register.c = carry;
        return;
    } else if (instruction.reg_1 == game_instructions.RegisterType.SP) {
        try cpu.emu.cycle(2);
        const e8: i8 = @bitCast(@as(u8, @truncate(right)));
        const sub: bool = e8 < 0;
        const sp: u16 = @intCast(left);

        const half_carry: u1 = @intFromBool(((sp & 0xF) + (right & 0xF)) >= 0x10);
        const overflow: u1 = @intFromBool(((sp & 0xFF) + (right & 0xFF)) >= 0x100);
        var result: u16 = 0;

        if (sub) {
            result = @subWithOverflow(sp, @abs(e8))[0];
        } else {
            result = @addWithOverflow(sp, @abs(e8))[0];
        }

        try cpu.write_reg(instruction.reg_1, result);

        cpu.flag_register.z = 0;
        cpu.flag_register.n = 0;
        cpu.flag_register.h = half_carry;
        cpu.flag_register.c = overflow;
        return;
    } else {
        try cpu.emu.cycle(1);
        const overflow_result = add_with_carry_check_u16(left, right);
        const result: u16 = overflow_result[0];
        const carry: u1 = overflow_result[1];
        const half_carry: u1 = overflow_result[2];

        try cpu.write_reg(instruction.reg_1, result);
        if (!try game_instructions.reg_is_u8(instruction.reg_1)) {
            try cpu.emu.cycle(1);
        }
        cpu.flag_register.n = 0;
        cpu.flag_register.h = half_carry;
        cpu.flag_register.c = carry;
        return;
    }

    return game_errors.EmuErrors.ProcNotImplemented;
}

fn proc_adc(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    try cpu.emu.cycle(1);
    const right: u8 = @truncate(cpu.fetched_data);
    const left: u8 = @truncate(try cpu.read_reg(instruction.reg_1));
    const carry_value: u8 = cpu.flag_register.c;

    const overflow_result_1 = add_with_carry_check_u8(right, carry_value);
    const overflow_result_2 = add_with_carry_check_u8(left, overflow_result_1[0]);

    const result: u8 = overflow_result_2[0];
    const carry: u1 = overflow_result_1[1] | overflow_result_2[1];
    const half_carry: u1 = overflow_result_1[2] | overflow_result_2[2];

    try cpu.write_reg(instruction.reg_1, result);

    cpu.flag_register.z = @intFromBool(result == 0);
    cpu.flag_register.n = 0;
    cpu.flag_register.h = half_carry;
    cpu.flag_register.c = carry;
}

fn proc_sub(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    try cpu.emu.cycle(1);
    const right: u8 = @truncate(cpu.fetched_data);
    const left: u8 = @truncate(try cpu.read_reg(instruction.reg_1));

    const overflow_result = sub_with_carry_check_u8(left, right);
    const result: u8 = overflow_result[0];
    const carry: u1 = overflow_result[1];
    const half_carry: u1 = overflow_result[2];

    try cpu.write_reg(instruction.reg_1, result);

    cpu.flag_register.z = @intFromBool(result == 0);
    cpu.flag_register.n = 1;
    cpu.flag_register.h = half_carry;
    cpu.flag_register.c = carry;

    return;
}

fn proc_sbc(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    const right: u8 = @truncate(cpu.fetched_data);
    const left: u8 = @truncate(try cpu.read_reg(instruction.reg_1));
    const carry_value: u8 = cpu.flag_register.c;

    const overflow_result_1 = sub_with_carry_check_u8(left, right);
    const overflow_result_2 = sub_with_carry_check_u8(overflow_result_1[0], carry_value);

    const result: u8 = overflow_result_2[0];
    const carry: u1 = overflow_result_1[1] | overflow_result_2[1];
    const half_carry: u1 = overflow_result_1[2] | overflow_result_2[2];

    try cpu.write_reg(instruction.reg_1, result);

    cpu.flag_register.z = @intFromBool(result == 0);
    cpu.flag_register.n = 1;
    cpu.flag_register.h = half_carry;
    cpu.flag_register.c = carry;
}

fn proc_and(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    try cpu.emu.cycle(1);
    const right: u8 = @truncate(cpu.fetched_data);
    const left: u8 = @truncate(try cpu.read_reg(instruction.reg_1));

    const result: u8 = left & right;

    try cpu.write_reg(instruction.reg_1, result);

    cpu.flag_register.z = @intFromBool(result == 0);
    cpu.flag_register.n = 0;
    cpu.flag_register.h = 1;
    cpu.flag_register.c = 0;
}

fn proc_or(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    try cpu.emu.cycle(1);
    const right: u8 = @truncate(cpu.fetched_data);
    const left: u8 = @truncate(try cpu.read_reg(instruction.reg_1));

    const result: u8 = left | right;

    try cpu.write_reg(instruction.reg_1, result);

    cpu.flag_register.z = @intFromBool(result == 0);
    cpu.flag_register.n = 0;
    cpu.flag_register.h = 0;
    cpu.flag_register.c = 0;
}

fn proc_cp(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    try cpu.emu.cycle(1);
    const right: u8 = @truncate(cpu.fetched_data);
    const left: u8 = @truncate(try cpu.read_reg(instruction.reg_1));

    const overflow_result = sub_with_carry_check_u8(left, right);
    const result: u8 = overflow_result[0];
    const carry: u1 = overflow_result[1];
    const half_carry: u1 = overflow_result[2];

    cpu.flag_register.z = @intFromBool(result == 0);
    cpu.flag_register.n = 1;
    cpu.flag_register.h = half_carry;
    cpu.flag_register.c = carry;

    return;
}

fn proc_rlca(cpu: *game_cpu.CPU) !void {
    const value: u8 = cpu.registers.a;
    const carry: u1 = @truncate(value >> 7);

    const result: u8 = value << 1 | @as(u8, carry);
    cpu.registers.a = result;

    cpu.flag_register.z = 0;
    cpu.flag_register.n = 0;
    cpu.flag_register.h = 0;
    cpu.flag_register.c = carry;
}

fn proc_rrca(cpu: *game_cpu.CPU) !void {
    const value: u8 = cpu.registers.a;
    const carry: u1 = @truncate(value);

    const result: u8 = (value >> 1) | (@as(u8, carry) << 7);
    cpu.registers.a = result;

    cpu.flag_register.z = 0;
    cpu.flag_register.n = 0;
    cpu.flag_register.h = 0;
    cpu.flag_register.c = carry;
}

fn proc_rla(cpu: *game_cpu.CPU) !void {
    const value: u8 = cpu.registers.a;
    const carry: u1 = @truncate(value >> 7);

    const previous_carry: u1 = cpu.flag_register.c;
    const result: u8 = (value << 1) | @as(u8, previous_carry);

    cpu.registers.a = result;

    cpu.flag_register.z = 0;
    cpu.flag_register.n = 0;
    cpu.flag_register.h = 0;
    cpu.flag_register.c = carry;
}

fn proc_rra(cpu: *game_cpu.CPU) !void {
    try cpu.emu.cycle(1);
    const value: u8 = cpu.registers.a;
    const carry: u1 = @truncate(value & 0x1);

    const previous_carry: u1 = cpu.flag_register.c;
    const result: u8 = (value >> 1) | (@as(u8, previous_carry) << 7);

    cpu.registers.a = result;

    cpu.flag_register.z = 0;
    cpu.flag_register.n = 0;
    cpu.flag_register.h = 0;
    cpu.flag_register.c = carry;
}

fn proc_daa(cpu: *game_cpu.CPU) !void {
    var u: u8 = 0;
    var fc: u1 = 0;

    if ((cpu.flag_register.h != 0) or (!(cpu.flag_register.n != 0) and ((cpu.registers.a & 0xF) > 9))) {
        u = 6;
    }

    if ((cpu.flag_register.c != 0) or (!(cpu.flag_register.n != 0) and (cpu.registers.a > 0x99))) {
        u = u | 0x60;
        fc = 1;
    }

    if (cpu.flag_register.n != 0) {
        cpu.registers.a = @subWithOverflow(cpu.registers.a, u)[0];
    } else {
        cpu.registers.a = @addWithOverflow(cpu.registers.a, u)[0];
    }

    cpu.flag_register.z = @intFromBool(cpu.registers.a == 0);
    cpu.flag_register.h = 0;
    cpu.flag_register.c = fc;
}

fn proc_cpl(cpu: *game_cpu.CPU) !void {
    cpu.registers.a = ~cpu.registers.a;

    cpu.flag_register.n = 1;
    cpu.flag_register.h = 1;
}

fn proc_scf(cpu: *game_cpu.CPU) !void {
    cpu.flag_register.n = 0;
    cpu.flag_register.h = 0;
    cpu.flag_register.c = 1;
}

fn proc_ccf(cpu: *game_cpu.CPU) !void {
    cpu.flag_register.n = 0;
    cpu.flag_register.h = 0;
    cpu.flag_register.c = ~cpu.flag_register.c;
}

fn proc_halt(cpu: *game_cpu.CPU) !void {
    cpu.halted = true;
}

fn proc_cb(cpu: *game_cpu.CPU) !void {
    const op: u8 = @truncate(cpu.fetched_data);
    const register: game_instructions.RegisterType = game_instructions.decode_register(@truncate(op & 0b111));
    const bit: u3 = @truncate((op >> 3) & 0b111);
    const bit_op: u8 = (op >> 6) & 0b11;

    const reg_value: u16 = try cpu.read_reg(register);
    var value: u8 = @truncate(reg_value);

    try cpu.emu.cycle(1);

    if (register == game_instructions.RegisterType.HL) {
        value = try cpu.emu.memory_bus.?.read(reg_value);
        try cpu.emu.cycle(2);
    }

    switch (bit_op) {
        1 => {
            //bit 0x40...0x7F
            const selected_bit: u1 = @intFromBool((value & (@as(u8, 1) << bit)) != 0);
            cpu.flag_register.z = ~selected_bit;
            cpu.flag_register.n = 0;
            cpu.flag_register.h = 1;
            return;
        },
        2 => {
            //res 0x80...0xBF
            const result: u8 = value & ~(@as(u8, 1) << bit);
            if (register == game_instructions.RegisterType.HL) {
                try cpu.emu.memory_bus.?.write(reg_value, result);
            } else {
                try cpu.write_reg(register, result);
            }
            return;
        },
        3 => {
            //set 0xC0...0xFF
            const result: u8 = value | (@as(u8, 1) << bit);
            if (register == game_instructions.RegisterType.HL) {
                try cpu.emu.memory_bus.?.write(reg_value, result);
            } else {
                try cpu.write_reg(register, result);
            }
            return;
        },
        else => {},
    }

    switch (bit) {
        0 => {
            //RLC
            const carry: u1 = @truncate(value >> 7);
            const result: u8 = (value << 1) | @as(u8, carry);

            if (register == game_instructions.RegisterType.HL) {
                try cpu.emu.memory_bus.?.write(reg_value, result);
            } else {
                try cpu.write_reg(register, result);
            }

            cpu.flag_register.z = @intFromBool(result == 0);
            cpu.flag_register.n = 0;
            cpu.flag_register.h = 0;
            cpu.flag_register.c = carry;
            return;
        },
        1 => {
            //RRC
            const carry: u1 = @truncate(value);
            const result: u8 = (value >> 1) | (@as(u8, carry) << 7);

            if (register == game_instructions.RegisterType.HL) {
                try cpu.emu.memory_bus.?.write(reg_value, result);
            } else {
                try cpu.write_reg(register, result);
            }

            cpu.flag_register.z = @intFromBool(result == 0);
            cpu.flag_register.n = 0;
            cpu.flag_register.h = 0;
            cpu.flag_register.c = carry;
            return;
        },
        2 => {
            //RL
            const carry: u1 = @truncate(value >> 7);
            const result: u8 = (value << 1) | @as(u8, cpu.flag_register.c);

            if (register == game_instructions.RegisterType.HL) {
                try cpu.emu.memory_bus.?.write(reg_value, result);
            } else {
                try cpu.write_reg(register, result);
            }

            cpu.flag_register.z = @intFromBool(result == 0);
            cpu.flag_register.n = 0;
            cpu.flag_register.h = 0;
            cpu.flag_register.c = carry;
            return;
        },
        3 => {
            //RR
            const carry: u1 = @truncate(value);
            const result: u8 = (value >> 1) | (@as(u8, cpu.flag_register.c) << 7);

            if (register == game_instructions.RegisterType.HL) {
                try cpu.emu.memory_bus.?.write(reg_value, result);
            } else {
                try cpu.write_reg(register, result);
            }

            cpu.flag_register.z = @intFromBool(result == 0);
            cpu.flag_register.n = 0;
            cpu.flag_register.h = 0;
            cpu.flag_register.c = carry;
            return;
        },
        4 => {
            //SLA
            const carry: u1 = @truncate(value >> 7);
            const result: u8 = value << 1;

            if (register == game_instructions.RegisterType.HL) {
                try cpu.emu.memory_bus.?.write(reg_value, result);
            } else {
                try cpu.write_reg(register, result);
            }

            cpu.flag_register.z = @intFromBool(result == 0);
            cpu.flag_register.n = 0;
            cpu.flag_register.h = 0;
            cpu.flag_register.c = carry;
            return;
        },
        5 => {
            //SRA
            const carry: u1 = @truncate(value);
            const b7: u1 = @truncate(value >> 7);
            const result: u8 = (value >> 1) | (@as(u8, b7) << 7);

            if (register == game_instructions.RegisterType.HL) {
                try cpu.emu.memory_bus.?.write(reg_value, result);
            } else {
                try cpu.write_reg(register, result);
            }

            cpu.flag_register.z = @intFromBool(result == 0);
            cpu.flag_register.n = 0;
            cpu.flag_register.h = 0;
            cpu.flag_register.c = carry;
            return;
        },
        6 => {
            //SWAP
            var old: u8 = @truncate(reg_value);
            if (register == game_instructions.RegisterType.HL) {
                const addr: u16 = reg_value;
                old = try cpu.emu.memory_bus.?.read(addr);
            }
            const hi: u8 = (old & 0x0F) << 4;
            const lo: u8 = (old & 0xF0) >> 4;
            const result: u8 = hi | lo;

            if (register == game_instructions.RegisterType.HL) {
                try cpu.emu.memory_bus.?.write(reg_value, result);
            } else {
                try cpu.write_reg(register, result);
            }

            cpu.flag_register.z = @intFromBool(result == 0);
            cpu.flag_register.n = 0;
            cpu.flag_register.h = 0;
            cpu.flag_register.c = 0;
            return;
        },
        7 => {
            //SRL
            const carry: u1 = @truncate(value);
            const result: u8 = value >> 1;

            if (register == game_instructions.RegisterType.HL) {
                try cpu.emu.memory_bus.?.write(reg_value, result);
            } else {
                try cpu.write_reg(register, result);
            }

            cpu.flag_register.z = @intFromBool(result == 0);
            cpu.flag_register.n = 0;
            cpu.flag_register.h = 0;
            cpu.flag_register.c = carry;
            return;
        },
    }

    return game_errors.EmuErrors.ProcNotImplemented;
}

pub fn proc(cpu: *game_cpu.CPU, instruction: game_instructions.Instruction) !void {
    switch (instruction.in_type) {
        game_instructions.InstructionType.NOP => try proc_nop(cpu),
        game_instructions.InstructionType.JP => try proc_jp(cpu, instruction),
        game_instructions.InstructionType.DI => try proc_di(cpu),
        game_instructions.InstructionType.LDI => try proc_ldi(cpu, instruction),
        game_instructions.InstructionType.LDD => try proc_ldd(cpu, instruction),
        game_instructions.InstructionType.LD => try proc_ld(cpu, instruction),
        game_instructions.InstructionType.LDH => try proc_ldh(cpu, instruction),
        game_instructions.InstructionType.CALL => try proc_call(cpu, instruction),
        game_instructions.InstructionType.DEC => try proc_dec(cpu, instruction),
        game_instructions.InstructionType.PUSH => try proc_push(cpu, instruction),
        game_instructions.InstructionType.POP => try proc_pop(cpu, instruction),
        game_instructions.InstructionType.JR => try proc_jr(cpu, instruction),
        game_instructions.InstructionType.RET => try proc_ret(cpu, instruction),
        game_instructions.InstructionType.RETI => try proc_reti(cpu, instruction),
        game_instructions.InstructionType.RST => try proc_rst(cpu, instruction),
        game_instructions.InstructionType.INC => try proc_inc(cpu, instruction),
        game_instructions.InstructionType.ADD => try proc_add(cpu, instruction),
        game_instructions.InstructionType.SUB => try proc_sub(cpu, instruction),
        game_instructions.InstructionType.ADC => try proc_adc(cpu, instruction),
        game_instructions.InstructionType.SBC => try proc_sbc(cpu, instruction),
        game_instructions.InstructionType.AND => try proc_and(cpu, instruction),
        game_instructions.InstructionType.XOR => try proc_xor(cpu, instruction),
        game_instructions.InstructionType.OR => try proc_or(cpu, instruction),
        game_instructions.InstructionType.CP => try proc_cp(cpu, instruction),
        game_instructions.InstructionType.RLCA => try proc_rlca(cpu),
        game_instructions.InstructionType.RRCA => try proc_rrca(cpu),
        game_instructions.InstructionType.RLA => try proc_rla(cpu),
        game_instructions.InstructionType.DAA => try proc_daa(cpu),
        game_instructions.InstructionType.SCF => try proc_scf(cpu),
        game_instructions.InstructionType.CPL => try proc_cpl(cpu),
        game_instructions.InstructionType.CCF => try proc_ccf(cpu),
        game_instructions.InstructionType.HALT => try proc_halt(cpu),
        game_instructions.InstructionType.CB => try proc_cb(cpu),
        game_instructions.InstructionType.EI => try proc_ei(cpu),
        game_instructions.InstructionType.RRA => try proc_rra(cpu),
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
