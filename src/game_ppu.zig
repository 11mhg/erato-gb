const std = @import("std");
const game_allocator = @import("game_allocator.zig");
const game_emu = @import("game_emu.zig");
const game_errors = @import("game_errors.zig");
const game_utils = @import("game_utils.zig");

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
    emu: *game_emu.Emu,
    dma: *DMA,

    pub fn init(emu: *game_emu.Emu) !*PPU {
        const allocator = game_allocator.GetAllocator();

        const ppu = try allocator.create(PPU);
        ppu.allocator = allocator;
        ppu.vram = try allocator.alloc(u8, 0x2000);
        ppu.oam = try allocator.alloc(OAM_Entry, 40);
        ppu.oam_raw = @ptrCast(ppu.oam.ptr);
        ppu.emu = emu;
        ppu.dma = try DMA.init(ppu);

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
        if (self.dma.active) {
            return 0xFF;
        }

        var new_address = address;
        if (new_address >= 0xFE00) {
            new_address -= 0xFE00;
        }
        return self.oam_raw[new_address];
    }

    pub fn oam_write(self: *PPU, address: u16, value: u8) !void {
        if (self.dma.active) {
            return;
        }

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

pub const DMA = struct {
    allocator: std.mem.Allocator,
    active: bool,
    byte: u8,
    value: u8,
    start_delay: u8,
    ppu: *PPU,

    pub fn init(ppu: *PPU) !*DMA {
        const allocator = game_allocator.GetAllocator();

        const dma = try allocator.create(DMA);
        dma.allocator = allocator;
        dma.active = false;
        dma.byte = 0;
        dma.value = 0;
        dma.start_delay = 0;
        dma.ppu = ppu;

        return dma;
    }

    pub fn start(self: *DMA, start_value: u8) void {
        self.active = true;
        self.byte = 0;
        self.start_delay = 2;
        self.value = start_value;
        std.debug.print("DMA START!\n", .{});
        game_utils.sleep(10.0);
    }

    pub fn tick(self: *DMA) !void {
        if (!self.active) {
            return;
        }

        if (self.start_delay != 0) {
            self.start_delay -= 1;
            return;
        }

        try self.ppu.oam_write(self.byte, //Addr
            try self.ppu.emu.memory_bus.?.read((@as(u16, @intCast(self.value)) * 0x100) + self.byte // value * 0x100 + byte
        ));
        self.byte += 1;
        self.active = self.byte < 0xA0;

        if (!self.active) {
            std.debug.print("DMA Done!\n", .{});
            game_utils.sleep(10.0);
        }
    }

    pub fn destroy(self: *DMA) void {
        self.allocator.destroy(self);
    }
};
