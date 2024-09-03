const std = @import("std");
const game_cpu = @import("game_cpu.zig");
const game_cart = @import("game_cart.zig");
const AssetNotFoundError = error{BootRomNotFoundError};

pub fn GetBootRoom(boot_rom_name: []const u8) ![]const u8 {
    const cgb_boot_rom: []const u8 = @embedFile("assets/bootroms/cgb_boot.bin");
    const dmg_boot_rom: []const u8 = @embedFile("assets/bootroms/dmg_boot.bin");
    if (std.mem.eql(u8, "cgb", boot_rom_name)) {
        return cgb_boot_rom;
    } else if (std.mem.eql(u8, "dmg", boot_rom_name)) {
        return dmg_boot_rom;
    }
    return &.{};
}

pub fn InitializeRegisters(cpu: *game_cpu.CPU, cart: *game_cart.Cart, boot_rom_name: []const u8) !void {
    if (std.mem.eql(u8, "dmg", boot_rom_name)) {
        cpu.registers.a = 0x01;
        cpu.flag_register.z = 1;
        cpu.flag_register.n = 0;
        if (cart.header.checksum != 0x00) {
            cpu.flag_register.c = 1;
            cpu.flag_register.h = 1;
        }
        cpu.registers.b = 0x00;
        cpu.registers.c = 0x13;
        cpu.registers.d = 0x00;
        cpu.registers.e = 0xD8;
        cpu.registers.h = 0x01;
        cpu.registers.l = 0x4D;

        cpu.registers.pc = 0x0100;
        cpu.registers.sp = 0xFFFE;

        cpu.ie_register = 0;
        cpu.int_flags = 0;
        cpu.interrupt_master_enable = false;
        cpu.enabling_ime = false;

        cpu.emu.timer.?.div = 0xABCC;
    }

    return;
}
