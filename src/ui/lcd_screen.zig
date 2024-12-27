const std = @import("std");
const zgui = @import("zgui");
const ztracy = @import("ztracy");
const game_ui = @import("../game_ui.zig");
const game_allocator = @import("../game_allocator.zig");
const ui_utils = @import("./utils.zig");

const XRES: usize = 160;
const YRES: usize = 144;

const ASPECT_RATIO_Y: f32 = @as(f32, @floatFromInt(XRES)) / @as(f32, @floatFromInt(YRES));
const ASPECT_RATIO_X: f32 = @as(f32, @floatFromInt(YRES)) / @as(f32, @floatFromInt(XRES));

pub const LCDScreen = struct {
    allocator: std.mem.Allocator,
    enabled: bool,
    ui: *game_ui.UI,

    screen_size: [2]f32,
    screen_offset: [2]f32,

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

    pub fn render(self: *LCDScreen, menu_offset: [2]f32) !bool {
        if (!self.enabled) {
            return false;
        }

        const display_size: [2]f32 = zgui.io.getDisplaySize();
        const dialog_size = [2]f32{ @floor(display_size[0] - menu_offset[0]), @floor(display_size[1] - menu_offset[1]) };

        zgui.setNextWindowPos(.{
            .x = @floor(menu_offset[0]), //@floor((dialog_size[0] / 2) + menu_offset[0]),
            .y = @floor(menu_offset[1]), //@floor((dialog_size[1] / 2) + menu_offset[1]),
            .cond = .always,
        });
        zgui.setNextWindowSize(.{ .w = dialog_size[0], .h = dialog_size[1], .cond = .always });

        const windowFlags = zgui.WindowFlags{
            .no_scrollbar = true,
            .no_collapse = true,
            .no_title_bar = true,
            .no_resize = true,
            .no_move = true,
            .no_background = true,
            .no_saved_settings = true,
            .no_bring_to_front_on_focus = true,
        };

        self.screen_size[0] = dialog_size[0];
        self.screen_size[1] = dialog_size[1];

        self.screen_offset[0] = menu_offset[0];
        self.screen_offset[1] = menu_offset[1];

        if (zgui.begin("MAIN_RENDER_SCREEN", .{ .popen = &self.enabled, .flags = windowFlags })) {
            try self.render_();
            zgui.end();
        }

        return false;
    }

    fn render_(self: *LCDScreen) !void {
        const render_lcd_zone = ztracy.ZoneNC(@src(), "Render LCD Screen", 0x00_00_FF_00);
        defer render_lcd_zone.End();

        const drawList = zgui.getWindowDrawList();
        var vMin: [2]f32 = zgui.getWindowContentRegionMin();
        var vMax: [2]f32 = zgui.getWindowContentRegionMax();

        vMin[0] += self.screen_offset[0];
        vMin[1] += self.screen_offset[1];

        //Give ourselves a bit of room at the bottom
        vMax[0] *= 0.9;
        vMax[1] *= 0.9;

        const center_drawable = [_]f32{ @divFloor((vMin[0] + vMax[0]), 2.0), @divFloor((vMin[1] + vMax[1]), 2.0) };

        var drawable_screenSize = [_]f32{
            vMax[0],
            @min(vMax[0] * ASPECT_RATIO_Y, vMax[1]),
        };
        if (vMax[1] <= vMax[0]) {
            drawable_screenSize[0] = @min(vMax[0], vMax[1] * ASPECT_RATIO_X);
            drawable_screenSize[1] = vMax[1];
        }
        drawable_screenSize[0] = @floor(drawable_screenSize[0]);
        drawable_screenSize[1] = @floor(drawable_screenSize[1]);

        const top_left = [_]f32{
            @floor(center_drawable[0] - @as(f32, @divFloor(drawable_screenSize[0], 2.0))),
            @floor(center_drawable[1] - @as(f32, @divFloor(drawable_screenSize[1], 2.0))),
        };
        const bot_right = [_]f32{
            @floor(top_left[0] + drawable_screenSize[0]),
            @floor(top_left[1] + drawable_screenSize[1]),
        };

        drawList.addRectFilled(.{ .pmin = top_left, .pmax = bot_right, .col = ui_utils.ImColor(17, 17, 17, 255) });

        const pixel_size = [_]f32{
            @ceil(drawable_screenSize[0] / @as(f32, @floatFromInt(XRES))),
            @ceil(drawable_screenSize[1] / @as(f32, @floatFromInt(YRES))),
        };

        var y: u16 = 0;
        while (y < @as(u16, @intCast(YRES))) : (y += 1) {
            var x: u16 = 0;
            while (x < @as(u16, @intCast(XRES))) : (x += 1) {
                const pmin = [_]f32{
                    top_left[0] + (@as(f32, @floatFromInt(x)) * pixel_size[0]),
                    top_left[1] + (@as(f32, @floatFromInt(y)) * pixel_size[1]),
                };
                const pmax = [_]f32{
                    pmin[0] + pixel_size[0],
                    pmin[1] + pixel_size[1],
                };

                var color: u32 = ui_utils.ImColor(255, 0, 127, 255);
                if (self.ui.emu.ppu) |ppu| {
                    color = ppu.video_buffer[x + (y * XRES)];
                }

                drawList.addRectFilled(.{
                    .pmin = pmin,
                    .pmax = pmax,
                    .col = color,
                });
            }
        }
        //std.debug.print("center: [{d},{d}]\n", .{ center_drawable[0], center_drawable[1] });
        //std.debug.print("  size: [{d},{d}]\n", .{ drawable_screenSize[0], drawable_screenSize[1] });
        //std.debug.print(" x0,y0: [{d},{d}]\n", .{ top_left[0], top_left[1] });
        //std.debug.print(" x1,y1: [{d},{d}]\n", .{ bot_right[0], bot_right[1] });
    }

    pub fn destroy(self: *LCDScreen) void {
        self.allocator.destroy(self);
    }
};
