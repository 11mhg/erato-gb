const std = @import("std");
const game_allocator = @import("game_allocator.zig");
const game_emu = @import("game_emu.zig");
const game_errors = @import("game_errors.zig");
const game_utils = @import("game_utils.zig");
const game_lcd = @import("game_lcd.zig");
const game_cpu = @import("game_cpu.zig");

const LINES_PER_FRAME: usize = 154;
const TICKS_PER_LINE: usize = 456;
const YRES: usize = 144;
const XRES: usize = 160;

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
    lcd: *game_lcd.LCDScreen,
    dma: *DMA,

    target_frame_time: u64,
    prev_frame_time: u64,
    start_timer: u64,
    frame_count: usize,

    current_frame: u32,
    line_ticks: u32,
    video_buffer: []u32,

    pub fn init(emu: *game_emu.Emu, lcd: *game_lcd.LCDScreen) !*PPU {
        const allocator = game_allocator.GetAllocator();

        const ppu = try allocator.create(PPU);
        ppu.allocator = allocator;
        ppu.vram = try allocator.alloc(u8, 0x2000);
        ppu.oam = try allocator.alloc(OAM_Entry, 40);
        ppu.oam_raw = @ptrCast(ppu.oam.ptr);
        ppu.emu = emu;
        ppu.lcd = lcd;
        ppu.dma = try DMA.init(ppu);

        @memset(ppu.vram, 0x00);

        ppu.current_frame = 0;
        ppu.line_ticks = 0;
        ppu.video_buffer = try allocator.alloc(u32, YRES * XRES * @sizeOf(u32));

        ppu.lcd.lcds_mode_set(game_lcd.LCD_MODE.MODE_OAM);

        @memset(ppu.oam, @bitCast(@as(u32, 0)));
        @memset(ppu.video_buffer, 0);

        ppu.target_frame_time = 1000 / 60; // 60 fps
        ppu.prev_frame_time = 0;
        ppu.start_timer = 0;
        ppu.frame_count = 0;

        return ppu;
    }

    pub fn tick(self: *PPU) void {
        self.line_ticks += 1;

        switch (self.lcd.lcds_mode()) {
            game_lcd.LCD_MODE.MODE_OAM => self.mode_oam(),
            game_lcd.LCD_MODE.MODE_XFER => self.mode_xfer(),
            game_lcd.LCD_MODE.MODE_HBLANK => self.mode_hblank(),
            game_lcd.LCD_MODE.MODE_VBLANK => self.mode_vblank(),
        }
    }

    pub fn destroy(self: *PPU) void {
        self.allocator.free(self.vram);
        self.allocator.free(self.oam);
        self.allocator.free(self.video_buffer);
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

    pub fn mode_oam(self: *PPU) void {
        if (self.line_ticks >= 80) {
            self.lcd.lcds_mode_set(game_lcd.LCD_MODE.MODE_XFER);
        }
    }
    pub fn mode_xfer(self: *PPU) void {
        if (self.line_ticks >= (80 + 172)) {
            self.lcd.lcds_mode_set(game_lcd.LCD_MODE.MODE_HBLANK);
        }
    }
    pub fn mode_vblank(self: *PPU) void {
        if (self.line_ticks >= TICKS_PER_LINE) {
            self.increment_ly();

            if (self.lcd.lcd_data.ly >= LINES_PER_FRAME) {
                self.lcd.lcds_mode_set(game_lcd.LCD_MODE.MODE_OAM);
                self.lcd.lcd_data.ly = 0;
            }

            self.line_ticks = 0;
        }
    }
    pub fn mode_hblank(self: *PPU) void {
        if (self.line_ticks >= TICKS_PER_LINE) {
            self.increment_ly();

            if (self.lcd.lcd_data.ly >= YRES) {
                self.lcd.lcds_mode_set(game_lcd.LCD_MODE.MODE_VBLANK);

                self.emu.cpu.?.request_interrupt(game_cpu.InterruptTypes.VBLANK);

                if (self.lcd.lcds_stat_int(game_lcd.STAT_SRC.SS_VBLANK)) {
                    self.emu.cpu.?.request_interrupt(game_cpu.InterruptTypes.LCD_STAT);
                }

                self.current_frame += 1;

                const end = self.emu.ui.?.get_ticks();
                const frame_time = end - self.prev_frame_time;

                if (frame_time < self.target_frame_time) {
                    const diff = self.target_frame_time - frame_time;
                    self.emu.ui.?.delay(diff);
                }

                if ((end - self.start_timer) >= 1000) {
                    const fps = self.frame_count;
                    self.start_timer = end;
                    self.frame_count = 0;
                    std.debug.print("FPS: {d}\n", .{fps});
                }

                self.frame_count += 1;
                self.prev_frame_time = frame_time;
            } else {
                self.lcd.lcds_mode_set(game_lcd.LCD_MODE.MODE_OAM);
            }

            self.line_ticks = 0;
        }
    }

    fn increment_ly(self: *PPU) void {
        self.lcd.lcd_data.ly += 1;

        const comp_val: bool = self.lcd.lcd_data.ly == self.lcd.lcd_data.ly_compare;
        self.lcd.lcds_lyc_set(comp_val);

        if (comp_val) {
            if (self.lcd.lcds_stat_int(game_lcd.STAT_SRC.SS_LYC)) {
                self.emu.cpu.?.request_interrupt(game_cpu.InterruptTypes.LCD_STAT);
            }
        }
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
    }

    pub fn destroy(self: *DMA) void {
        self.allocator.destroy(self);
    }
};
