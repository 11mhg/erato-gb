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
    cgb_palette: u3, //cgb_pn
    bank: u1, //cgb_vram_bank
    dmg_palette: u1, //pn
    x_flip: u1,
    y_flip: u1,
    priority: u1,
};

const OAM_Entry = packed struct(u32) { y: u8, x: u8, tile: u8, flags: OAM_Attribute_Flag };

fn cast(comptime source_type: type, comptime target_type: type, value: source_type) target_type {
    return @as(target_type, @intCast(value));
}

pub const PPU = struct {
    allocator: std.mem.Allocator,
    vram: []u8,
    oam: []OAM_Entry,
    oam_raw: [*]u8,
    emu: *game_emu.Emu,
    lcd: *game_lcd.LCDScreen,
    dma: *DMA,
    pixel_fifo_manager: *PixelFifoManager,

    line_sprite_count: u8,
    line_sprites: std.ArrayList(OAM_Entry),

    fetched_oam_entry_count: u8,
    fetched_oam_entries: [3]OAM_Entry,

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

        ppu.pixel_fifo_manager = try PixelFifoManager.init();

        ppu.line_sprite_count = 0;
        ppu.fetched_oam_entry_count = 0;

        ppu.line_sprites = std.ArrayList(OAM_Entry).init(ppu.allocator);

        return ppu;
    }

    pub fn tick(self: *PPU) !void {
        self.line_ticks += 1;

        switch (self.lcd.lcds_mode()) {
            game_lcd.LCD_MODE.MODE_OAM => try self.mode_oam(),
            game_lcd.LCD_MODE.MODE_XFER => try self.mode_xfer(),
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

    fn load_line_sprites(self: *PPU) !void {
        const cur_y: u8 = self.lcd.lcd_data.ly;
        const sprite_height: u8 = self.lcd.obj_size();

        self.line_sprites.shrinkAndFree(0);

        var i: usize = 0;
        while (i < 40) : (i += 1) {
            const e: *OAM_Entry = &(self.oam[i]);

            if (e.x == 0) {
                // x = 0 means not visible
                continue;
            }

            if (self.line_sprite_count >= 10) {
                // too many sprites! We're done
                break;
            }

            if ((e.y <= (cur_y + 16)) and ((e.y + sprite_height) > (cur_y + 16))) {
                // This current line
                if (self.line_sprites.items.len == 0) {
                    const entry: *OAM_Entry = try self.line_sprites.addOne();
                    entry.* = e.*;

                    self.line_sprite_count += 1;
                }

                var entry_to_check: u8 = 0;
                while (entry_to_check < self.line_sprites.items.len) : (entry_to_check += 1) {
                    const previous_entry: *OAM_Entry = &self.line_sprites.items[entry_to_check];
                    if (e.x > previous_entry.x) {
                        // Insert ourselves
                        try self.line_sprites.insert(entry_to_check, e.*);
                        self.line_sprite_count += 1;
                        break;
                    } else if (entry_to_check + 1 == self.line_sprites.items.len) {
                        const entry: *OAM_Entry = try self.line_sprites.addOne();
                        entry.* = e.*;
                        self.line_sprite_count += 1;
                        break;
                    }
                }
                // self.line_sprites should be ordered in descending X order i.e. [ .x = 5, .x = 3, .x = 1 ]
            }
        }
    }

    pub fn mode_oam(self: *PPU) !void {
        if (self.line_ticks >= 80) {
            self.lcd.lcds_mode_set(game_lcd.LCD_MODE.MODE_XFER);

            self.pixel_fifo_manager.cur_fetch_state = FETCH_STATE.FS_TILE;
            self.pixel_fifo_manager.line_x = 0;
            self.pixel_fifo_manager.fetch_x = 0;
            self.pixel_fifo_manager.pushed_x = 0;
            self.pixel_fifo_manager.fifo_x = 0;
        }

        if (self.line_ticks == 1) {
            // read oam on the first tick only
            self.line_sprite_count = 0;

            try self.load_line_sprites();
        }
    }
    pub fn mode_xfer(self: *PPU) !void {
        try self.pipeline_process();

        const pushed_x: usize = @intCast(self.pixel_fifo_manager.pushed_x);
        if (pushed_x >= XRES) {
            try self.pipeline_fifo_reset();

            self.lcd.lcds_mode_set(game_lcd.LCD_MODE.MODE_HBLANK);

            if (self.lcd.lcds_stat_int(game_lcd.STAT_SRC.SS_HBLANK)) {
                self.emu.cpu.?.request_interrupt(game_cpu.InterruptTypes.LCD_STAT);
            }
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

                const end = self.emu.get_time();
                const frame_time = end - self.prev_frame_time;

                if (frame_time < self.target_frame_time) {
                    const diff = self.target_frame_time - frame_time;
                    self.emu.ui.?.delay(diff / 2);
                }

                if ((end - self.start_timer) >= 1000) {
                    self.start_timer = end;
                    self.frame_count = 0;
                }

                self.frame_count += 1;
                self.prev_frame_time = self.emu.get_time();
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

    fn pixel_fifo_push(self: *PPU, value: u32) !void {
        try self.pixel_fifo_manager.push(value);
    }

    fn pixel_fifo_pop(self: *PPU) !u32 {
        return try self.pixel_fifo_manager.pop();
    }

    fn pipeline_process(self: *PPU) !void {
        self.pixel_fifo_manager.map_y = @addWithOverflow(self.lcd.lcd_data.ly, self.lcd.lcd_data.scroll_y)[0];
        self.pixel_fifo_manager.map_x = @addWithOverflow(self.pixel_fifo_manager.fetch_x, self.lcd.lcd_data.scroll_x)[0];

        self.pixel_fifo_manager.tile_y = @mulWithOverflow((@addWithOverflow(self.lcd.lcd_data.ly, self.lcd.lcd_data.scroll_y)[0] % 8), 2)[0];

        if ((self.line_ticks & 0b1) == 0) {
            // on the even lines
            try self.pipeline_fetch_pixel();
        }

        try self.pipeline_push_pixel();
    }

    fn pipeline_fifo_add(self: *PPU) !bool {
        if (self.pixel_fifo_manager.get_fifo_size() > 8) {
            //fifo is full
            return false;
        }

        const x: i32 = @as(i32, @intCast(self.pixel_fifo_manager.fetch_x)) - @as(i32, @intCast(8 - (self.lcd.lcd_data.scroll_x % 8)));

        var bit: i32 = 7;
        while (bit >= 0) : (bit -= 1) {
            const bit_shift: u3 = @intCast(bit);
            const res_b1: u8 = @intFromBool(!!((self.pixel_fifo_manager.bgw_fetch_data[1] & (@as(u8, 1) << bit_shift)) != 0));
            const res_b2: u8 = @intFromBool(!!((self.pixel_fifo_manager.bgw_fetch_data[2] & (@as(u8, 1) << bit_shift)) != 0));
            const hi: u8 = res_b1;
            const lo: u8 = res_b2 << 1;

            var color: u32 = self.lcd.lcd_data.bg_colors[hi | lo];

            if (!self.lcd.bgw_enable()) {
                color = self.lcd.lcd_data.bg_colors[0];
            }

            if (self.lcd.obj_enable()) {
                color = self.fetch_sprite_pixels(bit, color, hi | lo);
            }

            if (x >= 0) {
                try self.pixel_fifo_push(color);
                self.pixel_fifo_manager.fifo_x += 1;
            }
        }
        return true;
    }

    fn fetch_sprite_pixels(self: *PPU, _: i32, color: u32, bg_color: u8) u32 {
        var return_color: u32 = color;
        for (0..self.fetched_oam_entry_count) |i| {
            const sp_x: i32 = (@as(i32, @intCast(self.fetched_oam_entries[i].x)) - 8) +
                (@as(i32, @intCast(self.lcd.lcd_data.scroll_x % 8)));
            if (sp_x + 8 < self.pixel_fifo_manager.fifo_x) {
                // Passed this pixel point...
                continue;
            }

            const offset: i32 = @as(i32, @intCast(self.pixel_fifo_manager.fifo_x)) - sp_x;

            if ((offset < 0) or (offset > 7)) {
                // out of bounds
                continue;
            }

            var bit_shift: u3 = @intCast(7 - offset);
            if (self.fetched_oam_entries[i].flags.x_flip != 0) {
                bit_shift = @intCast(offset);
            }

            const res_b1: u8 = @intFromBool(!!((self.pixel_fifo_manager.fetch_entry_data[i * 2] & (@as(u8, 1) << bit_shift)) != 0));
            const res_b2: u8 = @intFromBool(!!((self.pixel_fifo_manager.fetch_entry_data[(i * 2) + 1] & (@as(u8, 1) << bit_shift)) != 0));
            const new_hi: u8 = res_b1;
            const new_lo: u8 = res_b2 << 1;

            const bg_priority: bool = self.fetched_oam_entries[i].flags.priority != 0;

            if ((new_hi | new_lo) == 0) {
                continue;
            }

            if (!bg_priority or bg_color == 0) {
                return_color = if (self.fetched_oam_entries[i].flags.dmg_palette != 0) self.lcd.lcd_data.sp2_colors[new_hi | new_lo] else self.lcd.lcd_data.sp1_colors[new_hi | new_lo];

                if ((new_hi | new_lo) != 0) {
                    break;
                }
            }
        }
        return return_color;
    }

    fn pipeline_fifo_reset(self: *PPU) !void {
        while (self.pixel_fifo_manager.get_fifo_size() > 0) {
            _ = try self.pixel_fifo_pop();
        }
    }

    fn pipeline_load_sprite_tile(self: *PPU) void {
        var entry_index: usize = self.line_sprites.items.len - 1;

        while (entry_index < self.line_sprites.items.len) : (entry_index = @subWithOverflow(entry_index, 1)[0]) {
            const current_entry: OAM_Entry = self.line_sprites.items[entry_index];
            const sp_x: i32 = (@as(i32, @intCast(current_entry.x)) - 8) +
                (@as(i32, @intCast(self.lcd.lcd_data.scroll_x % 8)));

            const fetch_x_i32: i32 = cast(u8, i32, self.pixel_fifo_manager.fetch_x);
            if (((sp_x >= fetch_x_i32) and (sp_x < (fetch_x_i32 + 8))) or
                (((sp_x + 8) >= fetch_x_i32) and ((sp_x + 8) <= (fetch_x_i32 + 8))))
            {
                // A valid sprite needed to be fetched
                self.fetched_oam_entries[self.fetched_oam_entry_count] = current_entry;
                self.fetched_oam_entry_count += 1;
            }

            if (self.fetched_oam_entry_count >= 3) {
                // leave after loading three entries
                break;
            }
        }
    }

    fn pipeline_fetch_pixel(self: *PPU) !void {
        switch (self.pixel_fifo_manager.cur_fetch_state) {
            FETCH_STATE.FS_TILE => {
                self.fetched_oam_entry_count = 0;

                if (self.lcd.bgw_enable()) {
                    const addr: u16 = self.lcd.bg_tilemap() +
                        (cast(u8, u16, self.pixel_fifo_manager.map_x) / 8) +
                        ((cast(u8, u16, self.pixel_fifo_manager.map_y) / 8) * 32);
                    const data: u8 = try self.emu.memory_bus.?.read(addr);
                    self.pixel_fifo_manager.bgw_fetch_data[0] = data;

                    if (self.lcd.bg_window_tiles() == 0x8800) {
                        const newFetchData = @addWithOverflow(self.pixel_fifo_manager.bgw_fetch_data[0], 128);
                        self.pixel_fifo_manager.bgw_fetch_data[0] = newFetchData[0];
                    }
                }

                if (self.lcd.obj_enable() and (self.line_sprites.items.len > 0)) {
                    self.pipeline_load_sprite_tile();
                }

                self.pixel_fifo_manager.cur_fetch_state = FETCH_STATE.FS_DATA0;
                self.pixel_fifo_manager.fetch_x += 8;
            },
            FETCH_STATE.FS_DATA0 => {
                const addr: u16 = self.lcd.bg_window_tiles() +
                    (cast(u8, u16, self.pixel_fifo_manager.bgw_fetch_data[0]) * 16) +
                    (cast(u8, u16, self.pixel_fifo_manager.tile_y));
                const data: u8 = try self.emu.memory_bus.?.read(addr);
                self.pixel_fifo_manager.bgw_fetch_data[1] = data;

                try self.pipeline_load_sprite_data(0);

                self.pixel_fifo_manager.cur_fetch_state = FETCH_STATE.FS_DATA1;
            },
            FETCH_STATE.FS_DATA1 => {
                const addr: u16 = self.lcd.bg_window_tiles() +
                    (cast(u8, u16, self.pixel_fifo_manager.bgw_fetch_data[0]) * 16) +
                    (cast(u8, u16, self.pixel_fifo_manager.tile_y) + 1);
                const data: u8 = try self.emu.memory_bus.?.read(addr);
                self.pixel_fifo_manager.bgw_fetch_data[2] = data;

                try self.pipeline_load_sprite_data(1);

                self.pixel_fifo_manager.cur_fetch_state = FETCH_STATE.FS_IDLE;
            },
            FETCH_STATE.FS_IDLE => {
                self.pixel_fifo_manager.cur_fetch_state = FETCH_STATE.FS_PUSH;
            },
            FETCH_STATE.FS_PUSH => {
                if (try self.pipeline_fifo_add()) {
                    self.pixel_fifo_manager.cur_fetch_state = FETCH_STATE.FS_TILE;
                }
            },
        }
    }

    fn pipeline_load_sprite_data(self: *PPU, offset: u1) !void {
        const cur_y: u8 = self.lcd.lcd_data.ly;
        const sprite_height: u8 = self.lcd.obj_size();

        for (0..self.fetched_oam_entry_count) |i| {
            var ty: u16 = ((cast(u8, u16, cur_y) + 16) - cast(u8, u16, self.fetched_oam_entries[i].y)) * 2;

            if (self.fetched_oam_entries[i].flags.y_flip != 0) {
                ty = ((cast(u8, u16, sprite_height) * 2) - 2) - ty;
            }

            var tile_index: u16 = @intCast(self.fetched_oam_entries[i].tile);

            if (sprite_height == 16) {
                tile_index &= ~@as(u16, @intCast(1));
            }

            const addr: u16 = 0x8000 + (tile_index * 16) + ty + cast(u1, u16, offset);
            self.pixel_fifo_manager.fetch_entry_data[(i * 2) + cast(u1, usize, offset)] = try self.emu.memory_bus.?.read(addr);
        }
    }

    fn pipeline_push_pixel(self: *PPU) !void {
        if (self.pixel_fifo_manager.get_fifo_size() > 8) {
            const pixel_data: u32 = try self.pixel_fifo_pop();

            if (self.pixel_fifo_manager.line_x >= (self.lcd.lcd_data.scroll_x % 8)) {
                self.video_buffer[self.pixel_fifo_manager.pushed_x + (self.lcd.lcd_data.ly * XRES)] = pixel_data;
                self.pixel_fifo_manager.pushed_x += 1;
            }

            self.pixel_fifo_manager.line_x += 1;
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

pub const FETCH_STATE = enum {
    FS_TILE,
    FS_DATA0,
    FS_DATA1,
    FS_IDLE,
    FS_PUSH,
};

pub const FifoEntry = struct {
    value: u32,
};

pub const PixelFifoManager = struct {
    allocator: std.mem.Allocator,

    cur_fetch_state: FETCH_STATE,
    pixel_fifo: std.fifo.LinearFifo(FifoEntry, .Dynamic),

    line_x: u8,
    pushed_x: u8,
    fetch_x: u8,
    bgw_fetch_data: [3]u8,
    fetch_entry_data: [6]u8, // OAM DATA
    map_y: u8,
    map_x: u8,
    tile_y: u8,
    tile_x: u8,

    fifo_x: u8,

    pub fn init() !*PixelFifoManager {
        const allocator = game_allocator.GetAllocator();

        var pixel_fifo_manager = try allocator.create(PixelFifoManager);
        pixel_fifo_manager.allocator = allocator;
        pixel_fifo_manager.pixel_fifo = std.fifo.LinearFifo(FifoEntry, .Dynamic).init(pixel_fifo_manager.allocator);

        pixel_fifo_manager.line_x = 0;
        pixel_fifo_manager.pushed_x = 0;
        pixel_fifo_manager.fetch_x = 0;

        pixel_fifo_manager.cur_fetch_state = FETCH_STATE.FS_TILE;

        return pixel_fifo_manager;
    }

    pub fn push(self: *PixelFifoManager, value: u32) !void {
        const fifoEntry: FifoEntry = FifoEntry{ .value = value };
        try self.pixel_fifo.writeItem(fifoEntry);
    }

    pub fn pop(self: *PixelFifoManager) !u32 {
        if (self.pixel_fifo.readItem()) |fifoEntry| {
            return fifoEntry.value;
        }
        return game_errors.EmuErrors.PixelFifoEmptyError;
    }

    pub fn get_fifo_size(self: *PixelFifoManager) u64 {
        return @as(u64, @intCast(self.pixel_fifo.readableLength()));
    }

    pub fn destroy(self: *PixelFifoManager) void {
        self.pixel_fifo.deinit();
        self.allocator.destroy(self);
    }
};
