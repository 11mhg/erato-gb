const std = @import("std");
const game_allocator = @import("game_allocator.zig");
const game_emu = @import("game_emu.zig");
const game_errors = @import("game_errors.zig");

const XRES: usize = 160;
const YRES: usize = 144;

const OAM_Attribute_Flag = packed struct(u8) {
    cgb_palette: u3,
    bank: u1,
    dmg_palette: u1,
    x_flip: u1,
    y_flip: u1,
    priority: u1,
};

const OAM_Entry = packed struct(u32) { y: u8, x: u8, tile: u8, flags: OAM_Attribute_Flag };

pub const PPU = struct {
    allocator: std.mem.Allocator,
    vram: []u8,
    oam: []OAM_Entry,
    oam_raw: [*]u8,

    pub fn init() !*PPU {
        const allocator = game_allocator.GetAllocator();

        const ppu = try allocator.create(PPU);
        ppu.allocator = allocator;
        ppu.vram = try allocator.alloc(u8, 0x2000);
        ppu.oam = try allocator.alloc(OAM_Entry, 40);
        ppu.oam_raw = @ptrCast(ppu.oam.ptr);

        @memset(ppu.vram, 0x00);
        @memset(ppu.oam, @bitCast(@as(u32, 0)));

        return ppu;
    }

    pub fn tick() void {}

    pub fn destroy(self: *PPU) void {
        self.allocator.free(self.vram);
        self.allocator.free(self.oam);
        self.allocator.destroy(self);
    }

    pub fn oam_read(self: *PPU, address: u16) !u8 {
        var new_address = address;
        if (new_address >= 0xFE00) {
            new_address -= 0xFE00;
        }
        return self.oam_raw[new_address];
    }

    pub fn oam_write(self: *PPU, address: u16, value: u8) !void {
        var new_address = address;
        if (new_address >= 0xFE00) {
            new_address -= 0xFE00;
        }
        self.oam_raw[new_address] = value;
        return;
    }

    pub fn vram_read(self: *PPU, address: u16) !u8 {
        const new_addr = address - 0x8000;
        return self.vram[new_addr];
    }

    pub fn vram_write(self: *PPU, address: u16, value: u8) !void {
        const new_addr = address - 0x8000;
        self.vram[new_addr] = value;
        return;
    }
};
