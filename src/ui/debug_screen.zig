const std = @import("std");
const zgui = @import("zgui");
const ztracy = @import("ztracy");
const game_ui = @import("../game_ui.zig");
const game_allocator = @import("../game_allocator.zig");
const ui_utils = @import("./utils.zig");

pub const DebugScreen = struct {
    allocator: std.mem.Allocator,
    enabled: bool,
    ui: *game_ui.UI,

    pub fn init(ui: *game_ui.UI) !*DebugScreen {
        const allocator = game_allocator.GetAllocator();

        const debugScreen = try allocator.create(DebugScreen);
        debugScreen.allocator = allocator;
        debugScreen.enabled = false;
        debugScreen.ui = ui;
        return debugScreen;
    }

    pub fn enable(self: *DebugScreen) void {
        self.enabled = true;
    }

    pub fn render(self: *DebugScreen) !bool {
        if (!self.enabled) {
            return false;
        }

        const display_size = zgui.io.getDisplaySize();
        const dialog_size = [2]f32{ @floor(display_size[0] * 0.9), @floor(display_size[1] * 0.9) };

        zgui.setNextWindowPos(.{
            .x = @floor(display_size[0] / 2),
            .y = @floor(display_size[1] / 2),
            .cond = .first_use_ever,
        });
        zgui.setNextWindowSize(.{ .w = dialog_size[0], .h = dialog_size[1], .cond = .first_use_ever });

        const windowFlags = zgui.WindowFlags{ .no_collapse = true };
        if (zgui.begin("Debug Screen", .{ .popen = &self.enabled, .flags = windowFlags })) {
            try self.render_();
            zgui.end();
        }

        return false;
    }

    fn render_(self: *DebugScreen) !void {
        const render_debug_zone = ztracy.ZoneNC(@src(), "Render Debug Screen", 0x00_00_FF_00);
        defer render_debug_zone.End();

        const drawList = zgui.getWindowDrawList();

        var vMin: [2]f32 = zgui.getWindowContentRegionMin();
        var vMax: [2]f32 = zgui.getWindowContentRegionMax();

        const windowPos = zgui.getWindowPos();

        vMin[0] += windowPos[0];
        vMax[0] += windowPos[0];
        vMin[1] += windowPos[1];
        vMax[1] += windowPos[1];

        const scale: u16 = 4;
        const pmin: [2]f32 = [2]f32{ vMin[0], vMin[1] };
        const pmax: [2]f32 = [2]f32{
            vMax[0],
            vMax[1],
        };

        drawList.addRectFilled(.{ .pmin = pmin, .pmax = pmax, .col = ui_utils.ImColor(17, 17, 17, 255) });

        var xDraw: u16 = @intFromFloat(vMin[0]);
        var yDraw: u16 = @intFromFloat(vMin[1]);
        var tileNum: u16 = 0;

        const addr: u16 = 0x8000;
        var y: u16 = 0;
        while (y < 24) : (y += 1) {
            var x: u16 = 0;
            while (x < 16) : (x += 1) {
                try self.display_tile(&drawList, addr, tileNum, xDraw + (x * scale), yDraw + (y * scale), scale);
                xDraw += (8 * scale);
                tileNum += 1;
            }

            yDraw += (8 * scale);
            xDraw = @intFromFloat(vMin[0]);
        }
    }

    fn display_tile(self: *DebugScreen, draw_list: *const zgui.DrawList, addr: u16, tileNum: u16, x: u16, y: u16, scale: u16) !void {
        var yTile: u16 = 0;

        while (yTile < 16) : (yTile += 2) {
            const b1: u8 = try self.ui.emu.memory_bus.?.read(addr + (tileNum * 16) + yTile);
            const b2: u8 = try self.ui.emu.memory_bus.?.read(addr + (tileNum * 16) + yTile + 1);

            var bit: i32 = 7;
            while (bit >= 0) : (bit -= 1) {
                const bit_shift: u3 = @intCast(bit);
                const res_b1: u8 = @intFromBool(!!((b1 & (@as(u8, 1) << bit_shift)) != 0));
                const res_b2: u8 = @intFromBool(!!((b2 & (@as(u8, 1) << bit_shift)) != 0));
                const hi: u8 = res_b1 << 1;
                const lo: u8 = res_b2;

                const color: u8 = hi | lo;

                const start_x: f32 = @as(f32, @floatFromInt(x)) + (@as(f32, @floatFromInt(@as(i32, 7) - bit)) * @as(f32, @floatFromInt(scale)));
                const start_y: f32 = @as(f32, @floatFromInt(y)) + @as(f32, @floatFromInt(yTile / 2 * scale));

                const end_x: f32 = start_x + @as(f32, @floatFromInt(scale));
                const end_y: f32 = start_y + @as(f32, @floatFromInt(scale));

                const pmin: [2]f32 = [2]f32{ start_x, start_y };
                const pmax: [2]f32 = [2]f32{ end_x, end_y };

                draw_list.*.addRectFilled(.{ .pmin = pmin, .pmax = pmax, .col = ui_utils.tile_colors[color] });
            }
        }
    }

    pub fn destroy(self: *DebugScreen) void {
        self.allocator.destroy(self);
    }
};
