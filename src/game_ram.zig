const std = @import("std");
const game_allocator = @import("game_allocator.zig");
const game_emu = @import("game_emu.zig");
const game_errors = @import("game_errors.zig");

pub const RAM = struct {
    allocator: std.mem.Allocator,
    wram: []u8,
    hram: []u8,

    pub fn init() !*RAM {
        const allocator = game_allocator.GetAllocator();

        const ram = try allocator.create(RAM);
        ram.allocator = allocator;
        ram.wram = try allocator.alloc(u8, 0x2000); // 8192
        ram.hram = try allocator.alloc(u8, 0x80); //  128

        @memset(ram.wram, 0x00);
        @memset(ram.hram, 0x00);

        return ram;
    }

    pub fn destroy(self: *RAM) void {
        self.allocator.free(self.wram);
        self.allocator.free(self.hram);
        self.allocator.destroy(self);
    }

    pub fn wram_read(self: *RAM, address: u16) !u8 {
        const new_addr = address - 0xC000;
        return self.wram[new_addr];
    }

    pub fn wram_write(self: *RAM, address: u16, value: u8) !void {
        const new_addr = address - 0xC000;
        self.wram[new_addr] = value;
        return;
    }

    pub fn hram_read(self: *RAM, address: u16) !u8 {
        const new_addr = address - 0xFF80;
        return self.hram[new_addr];
    }

    pub fn hram_write(self: *RAM, address: u16, value: u8) !void {
        std.debug.print("[HRAM] Write - 0x{X:0>4} - 0x{X:0>2}", .{ address, value });
        const new_addr = address - 0xFF80;
        self.hram[new_addr] = value;
        return;
    }
};
