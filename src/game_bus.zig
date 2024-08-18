const std = @import("std");
const game_errors = @import("game_errors.zig");
const game_allocator = @import("game_allocator.zig");
const game_emu = @import("game_emu.zig");

// 0000	3FFF	16 KiB ROM bank 00	From cartridge, usually a fixed bank
// 4000	7FFF	16 KiB ROM Bank 01–NN	From cartridge, switchable bank via mapper (if any)
// 8000	9FFF	8 KiB Video RAM (VRAM)	In CGB mode, switchable bank 0/1
// A000	BFFF	8 KiB External RAM	From cartridge, switchable bank if any
// C000	CFFF	4 KiB Work RAM (WRAM)
// D000	DFFF	4 KiB Work RAM (WRAM)	In CGB mode, switchable bank 1–7
// E000	FDFF	Echo RAM (mirror of C000–DDFF)	Nintendo says use of this area is prohibited.
// FE00	FE9F	Object attribute memory (OAM)
// FEA0	FEFF	Not Usable	Nintendo says use of this area is prohibited.
// FF00	FF7F	I/O Registers
// FF80	FFFE	High RAM (HRAM)
// FFFF	FFFF	Interrupt Enable register (IE)

pub const MemoryBus = struct {
    allocator: std.mem.Allocator,
    emu: *game_emu.Emu,
    map_boot_rom: bool,

    pub fn read(self: *MemoryBus, address: u16) !u8 {
        var cart = self.emu.cart.?.*;

        if (self.map_boot_rom and address < 0x0100) {
            const boot_rom = self.emu.boot_rom orelse {
                return game_errors.EmuErrors.NotImplementedError;
            };
            return boot_rom[address];
        }

        return switch (address) {
            0x0000...0x7FFF => try cart.read(address),
            0x8000...0x9FFF => return game_errors.EmuErrors.NotImplementedError,
            0xA000...0xBFFF => try cart.read(address),
            else => game_errors.EmuErrors.NotImplementedError,
        };
    }

    pub fn write(self: *MemoryBus, address: u16, value: u8) !void {
        var cart = self.emu.cart.?.*;
        switch (address) {
            0x0000...0x7FFF => {
                try cart.write(address, value);
                return;
            },
            0x8000...0x9FFF => {
                return game_errors.EmuErrors.NotImplementedError;
            },
            0xA000...0xBFFF => {
                try cart.write(address, value);
                return;
            },
            else => {
                return game_errors.EmuErrors.NotImplementedError;
            },
        }
    }

    pub fn init(emu: *game_emu.Emu) !*MemoryBus {
        const allocator = game_allocator.GetAllocator();
        const bus = try allocator.create(MemoryBus);

        bus.allocator = allocator;
        bus.emu = emu;
        bus.map_boot_rom = false;

        return bus;
    }

    pub fn destroy(self: *MemoryBus) void {
        self.allocator.destroy(self);
    }
};

// TESTS

test "Basic memory bus testing" {
    const emu = try game_emu.Emu.init();
    defer emu.destroy();
    try emu.prep_emu("./roms/dmg-acid2.gb");

    try emu.memory_bus.?.*.write(0x0000, 0xFF);
    try std.testing.expectEqual(0xFF, try emu.memory_bus.?.*.read(0x0000));
}
