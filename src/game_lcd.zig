const std = @import("std");
const game_allocator = @import("game_allocator.zig");
const game_emu = @import("game_emu.zig");
const ui_utils = @import("ui/utils.zig");
const game_errors = @import("game_errors.zig");

const LCDC = packed struct(u8) {
    bgw_enable: u1,
    obj_enable: u1,
    obj_size: u1,
    bg_tilemap: u1,
    bg_window_tiles: u1,
    window_enable: u1,
    window_tilemap: u1,
    lcd_ppu_enable: u1,
};

pub const LCDData = extern struct {
    lcdc: u8 align(1),
    lcds: u8 align(1),
    scroll_y: u8 align(1),
    scroll_x: u8 align(1),
    ly: u8 align(1),
    ly_compare: u8 align(1),
    dma: u8 align(1),
    bg_palette: u8 align(1),
    obj_palette: [2]u8 align(1),
    win_y: u8 align(1),
    win_x: u8 align(1),

    bg_colors: [4]u32 align(1),
    sp1_colors: [4]u32 align(1),
    sp2_colors: [4]u32 align(1),
};

pub const LCDScreen = struct {
    allocator: std.mem.Allocator,
    lcd_data_raw: []u8,
    lcd_data: *LCDData,
    emu: *game_emu.Emu,

    pub fn init(emu: *game_emu.Emu) !*LCDScreen {
        const allocator = game_allocator.GetAllocator();

        var lcdScreen: *LCDScreen = try allocator.create(LCDScreen);
        lcdScreen.allocator = allocator;
        lcdScreen.emu = emu;
        lcdScreen.lcd_data_raw = try allocator.alloc(u8, 60);
        @memset(lcdScreen.lcd_data_raw, 0x00);

        lcdScreen.lcd_data = @ptrCast(@as([]align(16) u8, @alignCast(lcdScreen.lcd_data_raw[0..60])));
        lcdScreen.lcd_data.lcdc = 0x91;
        lcdScreen.lcd_data.scroll_x = 0;
        lcdScreen.lcd_data.scroll_y = 0;
        lcdScreen.lcd_data.ly = 0;
        lcdScreen.lcd_data.ly_compare = 0;
        lcdScreen.lcd_data.bg_palette = 0xFC;
        lcdScreen.lcd_data.obj_palette[0] = 0xFF;
        lcdScreen.lcd_data.obj_palette[1] = 0xFF;

        lcdScreen.lcd_data.win_y = 0;
        lcdScreen.lcd_data.win_x = 0;

        for (0..4) |i| {
            lcdScreen.lcd_data.bg_colors[i] = ui_utils.tile_colors[i];
            lcdScreen.lcd_data.sp1_colors[i] = ui_utils.tile_colors[i];
            lcdScreen.lcd_data.sp2_colors[i] = ui_utils.tile_colors[i];
        }

        return lcdScreen;
    }

    pub fn destroy(self: *LCDScreen) void {
        self.allocator.free(self.lcd_data_raw);
        self.allocator.destroy(self);
    }

    pub fn bgw_enable(self: *LCDScreen) bool {
        const lcdc: LCDC = @ptrCast(&self.lcd_data.lcdc);
        return lcdc.bgw_enable != 0;
    }

    pub fn obj_enable(self: *LCDScreen) bool {
        const lcdc: LCDC = @ptrCast(&self.lcd_data.lcdc);
        return lcdc.obj_enable != 0;
    }

    pub fn obj_size(self: *LCDScreen) u8 {
        const lcdc: LCDC = @ptrCast(&self.lcd_data.lcdc);
        if (lcdc.obj_size != 0) {
            return 16;
        } else {
            return 8;
        }
    }

    pub fn bg_tilemap(self: *LCDScreen) u16 {
        const lcdc: LCDC = @ptrCast(&self.lcd_data.lcdc);
        if (lcdc.bg_tilemap == 0) {
            return 0x9800;
        } else {
            return 0x9C00;
        }
    }

    pub fn bg_window_tiles(self: *LCDScreen) u16 {
        const lcdc: LCDC = @ptrCast(&self.lcd_data.lcdc);
        if (lcdc.bg_window_tiles == 0) {
            return 0x8800;
        } else {
            return 0x8000;
        }
    }

    pub fn window_enable(self: *LCDScreen) bool {
        const lcdc: LCDC = @ptrCast(&self.lcd_data.lcdc);
        return lcdc.window_enable != 0;
    }

    pub fn window_tilemap(self: *LCDScreen) u16 {
        const lcdc: LCDC = @ptrCast(&self.lcd_data.lcdc);
        if (lcdc.window_tilemap == 0) {
            return 0x9800;
        } else {
            return 0x9C00;
        }
    }

    pub fn lcd_ppu_enable(self: *LCDScreen) bool {
        const lcdc: LCDC = @ptrCast(&self.lcd_data.lcdc);
        return lcdc.lcd_ppu_enable != 0;
    }

    pub fn lcds_mode(self: *LCDScreen) LCD_MODE {
        return @enumFromInt(self.lcd_data.lcds & 0b11);
    }

    pub fn lcds_mode_set(self: *LCDScreen, mode: LCD_MODE) void {
        self.lcd_data.lcds &= ~@as(u8, 0b11);
        self.lcd_data.lcds |= @as(u8, @intFromEnum(mode));
    }

    pub fn lcds_lyc(self: *LCDScreen) bool {
        return (self.lcd_data.lcds & 0b100) != 0;
    }

    pub fn lcds_lyc_set(self: *LCDScreen, val: bool) void {
        self.lcd_data.lcds &= ~@as(u8, 0b100);
        self.lcd_data.lcds = self.lcd_data.lcds | (@as(u8, @intFromBool(val)) << 2);
    }

    pub fn lcds_stat_int(self: *LCDScreen, stat: STAT_SRC) bool {
        return (self.lcd_data.lcds & @intFromEnum(stat)) != 0;
    }

    pub fn read(self: *LCDScreen, address: u16) u8 {
        const offset = address - 0xFF40;
        return self.lcd_data_raw[offset];
    }

    pub fn write(self: *LCDScreen, address: u16, value: u8) !void {
        const offset = address - 0xFF40;
        self.lcd_data_raw[offset] = value;

        if (offset == 6) {
            // 0xFF46 = DMA
            self.emu.ppu.?.dma.start(value);
        }

        if (address == 0xFF47) {
            try self.update_palette(value, 0);
        } else if (address == 0xFF48) {
            try self.update_palette(value & ~@as(u8, 0b11), 1);
        } else if (address == 0xFF49) {
            try self.update_palette(value & ~@as(u8, 0b11), 2);
        }
    }

    pub fn update_palette(self: *LCDScreen, palette_data: u8, pal: u8) !void {
        var colors = self.lcd_data.bg_colors;

        switch (pal) {
            1 => {
                colors = self.lcd_data.sp1_colors;
            },
            2 => {
                colors = self.lcd_data.sp2_colors;
            },
            else => {
                return;
            },
        }

        colors[0] = ui_utils.tile_colors[(palette_data & 0b11)];
        colors[1] = ui_utils.tile_colors[((palette_data >> 2) & 0b11)];
        colors[2] = ui_utils.tile_colors[((palette_data >> 4) & 0b11)];
        colors[3] = ui_utils.tile_colors[((palette_data >> 6) & 0b11)];
    }
};

pub const STAT_SRC = enum(u8) {
    SS_HBLANK = (1 << 3),
    SS_VBLANK = (1 << 4),
    SS_OAM = (1 << 5),
    SS_LYC = (1 << 6),
};

pub const LCD_MODE = enum {
    MODE_HBLANK,
    MODE_VBLANK,
    MODE_OAM,
    MODE_XFER,
};
