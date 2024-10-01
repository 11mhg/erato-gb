const std = @import("std");
const game_allocator = @import("game_allocator.zig");
const game_emu = @import("game_emu.zig");
const file_dialog = @import("ui/file_dialog.zig");
const debug_screen = @import("ui/debug_screen.zig");
const lcd_screen = @import("ui/lcd_screen.zig");

const zglfw = @import("zglfw");
const zgui = @import("zgui");
const zopengl = @import("zopengl");
const ztracy = @import("ztracy");

pub const window_name = "Erato-gb";
pub const gb_width: i32 = 160;
pub const gb_height: i32 = 144;
pub const aspect_ratio: f32 = @as(f32, @floatFromInt(gb_height)) / @as(f32, @floatFromInt(gb_width));

const gl = zopengl.bindings;

pub const UI = struct {
    allocator: std.mem.Allocator,
    window: *zglfw.Window,
    emu: *game_emu.Emu,
    file_dialog: *file_dialog.FileDialog,
    lcd_screen: *lcd_screen.LCDScreen,
    debug_screen: *debug_screen.DebugScreen,
    first_time: bool,

    time_0: u64,

    pub fn init(emu: *game_emu.Emu) !*UI {
        const allocator = game_allocator.GetAllocator();

        var ui: *UI = try allocator.create(UI);
        ui.allocator = allocator;
        ui.emu = emu;
        ui.file_dialog = try file_dialog.FileDialog.init();
        ui.lcd_screen = try lcd_screen.LCDScreen.init(ui);
        ui.debug_screen = try debug_screen.DebugScreen.init(ui);
        ui.first_time = true;

        // Initialize all GUI stuff here
        {
            try zglfw.init();
            zglfw.windowHintTyped(.client_api, .no_api);

            var window_width_float: f32 = @floor(720 * 0.5);
            var window_height_float: f32 = @floor(window_width_float * aspect_ratio);

            const primary_monitor = zglfw.Monitor.getPrimary();
            if (primary_monitor) |monitor| {
                const videoMode = try monitor.getVideoMode();
                const screen_width: f32 = @as(f32, @floatFromInt(videoMode.width));
                window_width_float = @floor(screen_width * 0.5);
                window_height_float = @floor(window_width_float * aspect_ratio);
            }

            const window_width: i32 = @intFromFloat(window_width_float);
            const window_height: i32 = @intFromFloat(window_height_float);

            std.debug.print("W: {d} H: {d}\n", .{ window_width, window_height });

            const gl_major: u32 = 4;
            const gl_minor: u32 = 0;
            zglfw.windowHintTyped(.context_version_major, gl_major);
            zglfw.windowHintTyped(.context_version_minor, gl_minor);
            zglfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
            zglfw.windowHintTyped(.opengl_forward_compat, true);
            zglfw.windowHintTyped(.client_api, .opengl_api);
            zglfw.windowHintTyped(.doublebuffer, false);

            ui.window = try zglfw.Window.create(window_width, window_height, window_name, null);
            ui.window.setSizeLimits(gb_width, gb_height, -1, -1);

            zglfw.makeContextCurrent(ui.window);
            zglfw.swapInterval(0);

            try zopengl.loadCoreProfile(zglfw.getProcAddress, gl_major, gl_minor);

            zgui.init(ui.allocator);

            const scale_factor = scale_factor: {
                const scale = ui.window.getContentScale();
                break :scale_factor @max(scale[0], scale[1]);
            };
            const style = zgui.getStyle();
            style.scaleAllSizes(scale_factor);
            style.window_rounding = 5.3;

            zgui.backend.init(ui.window);

            ui.setup_imgui_theme();
        }
        ui.time_0 = @intCast(std.time.milliTimestamp());
        // Done initializing gui stuff

        return ui;
    }

    pub fn setup_imgui_theme(_: *UI) void {
        // This style is from the dougbinks' gist: https://gist.github.com/dougbinks/8089b4bbaccaaf6fa204236978d165a9#file-imguiutils-h-L9-L93
        const style: *zgui.Style = zgui.getStyle();

        // light style from Pacôme Danhiez (user itamago) https://github.com/ocornut/imgui/pull/511#issuecomment-175719267
        style.alpha = 1.0;
        style.frame_rounding = 3.0;
        style.setColor(zgui.StyleCol.text, [4]f32{ 0.0, 0.0, 0.0, 1.0 });
        style.setColor(zgui.StyleCol.text_disabled, [4]f32{ 0.60, 0.60, 0.60, 1.00 });
        style.setColor(zgui.StyleCol.window_bg, [4]f32{ 0.94, 0.94, 0.94, 0.94 });
        style.setColor(zgui.StyleCol.child_bg, [4]f32{ 0.00, 0.00, 0.00, 0.00 });
        style.setColor(zgui.StyleCol.popup_bg, [4]f32{ 1.00, 1.00, 1.00, 0.94 });
        style.setColor(zgui.StyleCol.border, [4]f32{ 0.00, 0.00, 0.00, 0.39 });
        style.setColor(zgui.StyleCol.border_shadow, [4]f32{ 1.00, 1.00, 1.00, 0.10 });
        style.setColor(zgui.StyleCol.frame_bg, [4]f32{ 1.00, 1.00, 1.00, 0.94 });
        style.setColor(zgui.StyleCol.frame_bg_hovered, [4]f32{ 0.26, 0.59, 0.98, 0.40 });
        style.setColor(zgui.StyleCol.frame_bg_active, [4]f32{ 0.26, 0.59, 0.98, 0.67 });
        style.setColor(zgui.StyleCol.title_bg, [4]f32{ 0.96, 0.96, 0.96, 1.00 });
        style.setColor(zgui.StyleCol.title_bg_collapsed, [4]f32{ 1.00, 1.00, 1.00, 0.51 });
        style.setColor(zgui.StyleCol.title_bg_active, [4]f32{ 0.82, 0.82, 0.82, 1.00 });
        style.setColor(zgui.StyleCol.menu_bar_bg, [4]f32{ 0.86, 0.86, 0.86, 1.00 });
        style.setColor(zgui.StyleCol.scrollbar_bg, [4]f32{ 0.98, 0.98, 0.98, 0.53 });
        style.setColor(zgui.StyleCol.scrollbar_grab, [4]f32{ 0.69, 0.69, 0.69, 1.00 });
        style.setColor(zgui.StyleCol.scrollbar_grab_hovered, [4]f32{ 0.59, 0.59, 0.59, 1.00 });
        style.setColor(zgui.StyleCol.scrollbar_grab_active, [4]f32{ 0.49, 0.49, 0.49, 1.00 });
        style.setColor(zgui.StyleCol.check_mark, [4]f32{ 0.26, 0.59, 0.98, 1.00 });
        style.setColor(zgui.StyleCol.slider_grab, [4]f32{ 0.24, 0.52, 0.88, 1.00 });
        style.setColor(zgui.StyleCol.slider_grab_active, [4]f32{ 0.26, 0.59, 0.98, 1.00 });
        style.setColor(zgui.StyleCol.button, [4]f32{ 0.26, 0.59, 0.98, 0.40 });
        style.setColor(zgui.StyleCol.button_hovered, [4]f32{ 0.26, 0.59, 0.98, 1.00 });
        style.setColor(zgui.StyleCol.button_active, [4]f32{ 0.06, 0.53, 0.98, 1.00 });
        style.setColor(zgui.StyleCol.header, [4]f32{ 0.26, 0.59, 0.98, 0.31 });
        style.setColor(zgui.StyleCol.header_hovered, [4]f32{ 0.26, 0.59, 0.98, 0.80 });
        style.setColor(zgui.StyleCol.header_active, [4]f32{ 0.26, 0.59, 0.98, 1.00 });
        style.setColor(zgui.StyleCol.resize_grip, [4]f32{ 1.00, 1.00, 1.00, 0.50 });
        style.setColor(zgui.StyleCol.resize_grip_hovered, [4]f32{ 0.26, 0.59, 0.98, 0.67 });
        style.setColor(zgui.StyleCol.resize_grip_active, [4]f32{ 0.26, 0.59, 0.98, 0.95 });
        style.setColor(zgui.StyleCol.plot_lines, [4]f32{ 0.39, 0.39, 0.39, 1.00 });
        style.setColor(zgui.StyleCol.plot_lines_hovered, [4]f32{ 1.00, 0.43, 0.35, 1.00 });
        style.setColor(zgui.StyleCol.plot_histogram, [4]f32{ 0.90, 0.70, 0.00, 1.00 });
        style.setColor(zgui.StyleCol.plot_histogram_hovered, [4]f32{ 1.00, 0.60, 0.00, 1.00 });
        style.setColor(zgui.StyleCol.text_selected_bg, [4]f32{ 0.26, 0.59, 0.98, 0.35 });
        style.setColor(zgui.StyleCol.modal_window_dim_bg, [4]f32{ 0.20, 0.20, 0.20, 0.35 });
    }

    pub fn pre_render(self: *UI) void {
        const pre_render_zone = ztracy.ZoneNC(@src(), "Pre Render", 0x00_FF_00_00);
        defer pre_render_zone.End();
        zglfw.pollEvents();

        gl.clearBufferfv(gl.COLOR, 0, &[_]f32{ 0, 0, 0, 1.0 });

        const fb_size = self.window.getFramebufferSize();

        zgui.backend.newFrame(
            @intCast(fb_size[0]),
            @intCast(fb_size[1]),
        );

        return;
    }

    pub fn post_render(self: *UI) void {
        const post_render_zone = ztracy.ZoneNC(@src(), "Post Render", 0x00_FF_00_00);
        defer post_render_zone.End();
        zgui.backend.draw();
        self.window.swapBuffers();
    }

    pub fn render(self: *UI) !void {
        const render_zone = ztracy.ZoneNC(@src(), "Render", 0x00_FF_00_00);
        defer render_zone.End();
        var menu_size: [2]f32 = [2]f32{ 0, 0 };
        if (zgui.beginMainMenuBar()) {
            if (zgui.beginMenu("File", true)) {
                if (zgui.menuItem("Open", .{})) {
                    self.file_dialog.enable();
                }
                zgui.endMenu();
            }
            if (zgui.beginMenu("Debug", true)) {
                if (zgui.menuItem("Debug Screen", .{})) {
                    self.debug_screen.enable();
                }
                zgui.endMenu();
            }
            menu_size = zgui.getWindowSize();
            zgui.endMainMenuBar();
        }

        _ = try self.debug_screen.render();

        _ = try self.lcd_screen.render(.{ 0.0, menu_size[1] });

        if (try self.file_dialog.render()) {
            try self.emu.prep_emu(self.file_dialog.path.?);
        }

        if (zgui.begin("FPS", .{})) {
            const fps = zgui.io.getFramerate();
            zgui.text("{d} FPS", .{fps});
            zgui.end();
        }

        if (self.first_time) {
            self.first_time = false;
        }
    }

    pub fn delay(_: *UI, ms: u64) void {
        std.time.sleep(ms * std.time.ns_per_ms);
    }

    pub fn get_ticks(self: *UI) u64 {
        return @as(u64, @intCast(std.time.milliTimestamp())) - self.time_0;
    }

    pub fn destroy(self: *UI) void {
        self.file_dialog.destroy();
        self.debug_screen.destroy();
        zgui.backend.deinit();
        zgui.deinit();
        self.window.destroy();
        zglfw.terminate();
        self.allocator.destroy(self);
    }
};
