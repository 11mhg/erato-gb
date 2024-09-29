const std = @import("std");
const zgui = @import("zgui");
const ztracy = @import("ztracy");
const game_ui = @import("../game_ui.zig");
const game_allocator = @import("../game_allocator.zig");
const ui_utils = @import("./utils.zig");

pub const LCDScreen = struct {
    allocator: std.mem.Allocator,
    enabled: bool,
    ui: *game_ui.UI,

    pub fn init(ui: *game_ui.UI) !*LCDScreen {
        const allocator = game_allocator.GetAllocator();

        const lcdScreen = try allocator.create(LCDScreen);
        lcdScreen.allocator = allocator;
        lcdScreen.enabled = false;
        lcdScreen.ui = ui;
        return lcdScreen;
    }

    pub fn enable(self: *LCDScreen) void {
        self.enabled = true;
    }

    pub fn render(self: *LCDScreen, _: [2]f32) !bool {
        if (!self.enabled) {
            return false;
        }

        //const display_size = zgui.io.getDisplaySize();
        //const dialog_size = [2]f32{ @floor(display_size[0] * 0.9), @floor(display_size[1] * 0.9) };

        //zgui.setNextWindowPos(.{
        //    .x = @floor(display_size[0] / 2),
        //    .y = @floor(display_size[1] / 2),
        //    .cond = .first_use_ever,
        //});
        //zgui.setNextWindowSize(.{ .w = dialog_size[0], .h = dialog_size[1], .cond = .first_use_ever });

        //const windowFlags = zgui.WindowFlags{ .no_collapse = true };
        //if (zgui.begin("Debug Screen", .{ .popen = &self.enabled, .flags = windowFlags })) {
        //    try self.render_();
        //    zgui.end();
        //}

        return false;
    }

    fn render_(_: *LCDScreen) !void {
        const render_lcd_zone = ztracy.ZoneNC(@src(), "Render LCD Screen", 0x00_00_FF_00);
        defer render_lcd_zone.End();
    }

    pub fn destroy(self: *LCDScreen) void {
        self.allocator.destroy(self);
    }
};
