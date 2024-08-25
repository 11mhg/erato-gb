const std = @import("std");
const game_allocator = @import("game_allocator.zig");
const game_emu = @import("game_emu.zig");
const file_dialog = @import("ui/file_dialog.zig");

const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const zgui = @import("zgui");

pub const window_name = "Erato-gb";
pub const gb_width: i32 = 160;
pub const gb_height: i32 = 144;
pub const aspect_ratio: f32 = @as(f32, @floatFromInt(gb_height)) / @as(f32, @floatFromInt(gb_width));

pub const UI = struct {
    allocator: std.mem.Allocator,
    window: *zglfw.Window,
    gctx: *zgpu.GraphicsContext,
    emu: *game_emu.Emu,

    pub fn init(emu: *game_emu.Emu) !*UI {
        const allocator = game_allocator.GetAllocator();

        var ui: *UI = try allocator.create(UI);
        ui.allocator = allocator;
        ui.emu = emu;

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

            ui.window = try zglfw.Window.create(window_width, window_height, window_name, null);
            ui.window.setSizeLimits(gb_width, gb_height, -1, -1);

            ui.gctx = try zgpu.GraphicsContext.create(
                ui.allocator,
                .{
                    .window = ui.window,
                    .fn_getTime = @ptrCast(&zglfw.getTime),
                    .fn_getFramebufferSize = @ptrCast(&zglfw.Window.getFramebufferSize),
                    .fn_getWin32Window = @ptrCast(&zglfw.getWin32Window),
                    .fn_getX11Display = @ptrCast(&zglfw.getX11Display),
                    .fn_getX11Window = @ptrCast(&zglfw.getX11Window),
                    .fn_getWaylandDisplay = @ptrCast(&zglfw.getWaylandDisplay),
                    .fn_getWaylandSurface = @ptrCast(&zglfw.getWaylandWindow),
                    .fn_getCocoaWindow = @ptrCast(&zglfw.getCocoaWindow),
                },
                .{},
            );
            zgui.init(ui.allocator);

            zgui.backend.init(
                ui.window,
                ui.gctx.device,
                @intFromEnum(zgpu.GraphicsContext.swapchain_format),
                @intFromEnum(wgpu.TextureFormat.undef),
            );

            const scale_factor = scale_factor: {
                const scale = ui.window.getContentScale();
                break :scale_factor @max(scale[0], scale[1]);
            };

            zgui.getStyle().scaleAllSizes(scale_factor);
        }
        // Done initializing gui stuff

        return ui;
    }

    pub fn pre_render(self: *UI) void {
        zglfw.pollEvents();

        zgui.backend.newFrame(
            self.gctx.swapchain_descriptor.width,
            self.gctx.swapchain_descriptor.height,
        );

        //zgui.setNextWindowPos(.{ .x = 20.0, .y = 20.0, .cond = .first_use_ever });
        //zgui.setNextWindowSize(.{ .w = -1.0, .h = -1.0, .cond = .first_use_ever });

        return;
    }

    pub fn post_render(self: *UI) void {
        const swapchain_texv = self.gctx.swapchain.getCurrentTextureView();
        defer swapchain_texv.release();

        const commands = commands: {
            const encoder = self.gctx.device.createCommandEncoder(null);
            defer encoder.release();

            {
                const pass = zgpu.beginRenderPassSimple(encoder, .load, swapchain_texv, null, null, null);
                defer zgpu.endReleasePass(pass);
                zgui.backend.draw(pass);
            }

            break :commands encoder.finish(null);
        };
        defer commands.release();

        self.gctx.submit(&.{commands});
        _ = self.gctx.present();
    }

    pub fn render(self: *UI) void {
        const size = self.window.getSize();
        if (zgui.beginMainMenuBar()) {
            if (zgui.beginMenu("File", true)) {
                if (zgui.menuItem("Open", .{})) {
                    zgui.setNextWindowPos(.{
                        .x = @floor(@as(f32, @floatFromInt(size[0])) / 2),
                        .y = @floor(@as(f32, @floatFromInt(size[1])) / 2),
                        .cond = .first_use_ever,
                    });
                    zgui.setNextWindowSize(.{ .w = -1.0, .h = -1.0, .cond = .first_use_ever });
                    _ = file_dialog.open();
                }
                zgui.endMenu();
            }
            zgui.endMainMenuBar();
        }
    }

    pub fn destroy(self: *UI) void {
        zgui.backend.deinit();
        zgui.deinit();
        self.gctx.destroy(self.allocator);
        self.window.destroy();
        zglfw.terminate();
        self.allocator.destroy(self);
    }
};
