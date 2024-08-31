const std = @import("std");
const zgui = @import("zgui");
const game_allocator = @import("../game_allocator.zig");

pub const FileDialog = struct {
    allocator: std.mem.Allocator,
    enabled: bool,
    path: ?[]const u8,
    current_path: std.fs.Dir,
    search_term: [:0]u8,

    pub fn init() !*FileDialog {
        const allocator = game_allocator.GetAllocator();

        const fileDialog = try allocator.create(FileDialog);
        fileDialog.allocator = allocator;
        fileDialog.enabled = false;
        fileDialog.path = null;
        fileDialog.current_path = try std.fs.cwd().openDir(".", .{ .iterate = true });
        fileDialog.search_term = try allocator.allocSentinel(u8, 128, 0);
        @memset(fileDialog.search_term, 0);
        return fileDialog;
    }

    pub fn enable(self: *FileDialog) void {
        self.enabled = true;
    }

    pub fn render(self: *FileDialog) !bool {
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
        if (zgui.begin("FileDialog", .{ .flags = windowFlags })) {
            //if (zgui.beginTable("PathBar", .{
            //    .column = 3,
            //    .flags = .{},
            //    .outer_size = .{ 0.0, 0.0 },
            //    .inner_width = 0.0,
            //})) {
            //    zgui.tableSetupColumn("", .{
            //        .flags = .{ .width_stretch = true },
            //        .init_width_or_height = 0,
            //        .user_id = 0,
            //    });
            //    zgui.tableSetupColumn("", .{
            //        .flags = .{ .width_fixed = true },
            //        .init_width_or_height = 0,
            //        .user_id = 0,
            //    });
            //    zgui.tableSetupColumn("", .{
            //        .flags = .{ .width_stretch = true },
            //        .init_width_or_height = 0,
            //        .user_id = 0,
            //    });

            //    zgui.tableNextRow(.{});

            try self.render_();

            //    zgui.endTable();
            //}
            zgui.end();
        }

        if (self.path) |_| {
            self.enabled = false;
            return true;
        }

        return false;
    }

    fn render_(self: *FileDialog) !void {
        var search_term_entered = false;
        const full_current_path = try self.current_path.realpathAlloc(self.allocator, ".");
        defer self.allocator.free(full_current_path);

        zgui.beginGroup();
        if (zgui.beginChild("##NavigationBar", .{ .child_flags = .{ .auto_resize_y = true } })) {
            var it = std.mem.split(u8, full_current_path, std.fs.path.sep_str);

            var path_so_far: u64 = 0;
            while (it.next()) |elem| {
                if (elem.len == 0) {
                    continue;
                }
                const label: [:0]u8 = try slice_to_sentinel_terminated(elem, self.allocator);
                defer self.allocator.free(label);
                path_so_far = path_so_far + std.fs.path.sep_str.len + elem.len;
                zgui.sameLine(.{});
                zgui.text("{s}", .{std.fs.path.sep_str});
                zgui.sameLine(.{});
                if (zgui.button(label, .{})) {
                    self.current_path.close();
                    self.current_path = try std.fs.openDirAbsolute(full_current_path[0..path_so_far], .{ .iterate = true });
                }
            }
            zgui.sameLine(.{});
            zgui.text("|| Search: ", .{});
            zgui.sameLine(.{});

            if (zgui.inputText("##NavBarFilterSearch", .{ .buf = self.search_term, .flags = zgui.InputTextFlags{} })) {
                search_term_entered = true;
            }
            zgui.endChild();
        }
        zgui.endGroup();

        //zgui.tableNextRow(.{});
        zgui.beginGroup();
        if (zgui.beginChild("##FileArea", .{ .child_flags = zgui.ChildFlags{ .border = true }, .window_flags = zgui.WindowFlags{ .always_vertical_scrollbar = true } })) {
            const final_search_term = try sentinel_terminated_to_slice(self.search_term, self.allocator);
            defer self.allocator.free(final_search_term);

            if (zgui.selectable("..", .{ .flags = .{ .allow_double_click = true } })) {
                if (zgui.isMouseDoubleClicked(zgui.MouseButton.left)) {
                    const parent_dir = std.fs.path.dirname(full_current_path);
                    if (parent_dir) |valid_parent_dir| {
                        self.current_path.close();
                        self.current_path = try std.fs.openDirAbsolute(valid_parent_dir, .{ .iterate = true });
                    }
                    @memset(self.search_term, 0);
                }
            }

            var path_it = self.current_path.iterate();
            while (try path_it.next()) |entry| {
                const name: []const u8 = entry.name;
                const kind: std.fs.File.Kind = entry.kind;

                if (final_search_term.len > 0) {
                    if (!std.mem.containsAtLeast(u8, name, 1, final_search_term)) {
                        continue;
                    }
                }

                const name_sentinel: [:0]const u8 = try slice_to_sentinel_terminated(name, self.allocator);
                defer self.allocator.free(name_sentinel);

                if (zgui.selectable(name_sentinel, .{ .flags = .{ .allow_double_click = true } })) {
                    //selected this path or file;
                    if (kind == std.fs.File.Kind.directory) {
                        if (zgui.isMouseDoubleClicked(zgui.MouseButton.left)) {
                            const paths = [_][]const u8{ full_current_path, name };
                            const new_full_path = try std.fs.path.join(self.allocator, &paths);
                            defer self.allocator.free(new_full_path);
                            self.current_path.close();
                            self.current_path = try std.fs.openDirAbsolute(new_full_path, .{ .iterate = true });
                            @memset(self.search_term, 0);
                        }
                    } else if (kind == std.fs.File.Kind.file) {
                        if (zgui.isMouseDoubleClicked(zgui.MouseButton.left)) {
                            const paths = [_][]const u8{ full_current_path, name };
                            const new_full_path = try std.fs.path.join(self.allocator, &paths);
                            defer self.allocator.free(new_full_path);

                            if (self.path) |value| {
                                self.allocator.free(value);
                                self.path = value;
                            }
                            self.path = try self.allocator.dupe(u8, new_full_path);
                            @memset(self.search_term, 0);
                        }
                    }
                }
            }

            zgui.endChild();
        }
        zgui.endGroup();
    }

    pub fn destroy(self: *FileDialog) void {
        if (self.path) |value| {
            self.allocator.free(value);
        }

        self.allocator.free(self.search_term);

        self.current_path.close();
        self.allocator.destroy(self);
    }
};

fn sentinel_terminated_to_slice(sentinel: [:0]const u8, allocator: std.mem.Allocator) ![]u8 {
    var i: usize = 0;
    var count: usize = 0;
    while (sentinel[i] != 0) : (i += 1) {
        count += 1;
    }

    const slice: []u8 = try allocator.alloc(u8, count);
    for (0..count) |idx| {
        slice[idx] = sentinel[idx];
    }

    return slice;
}

fn slice_to_sentinel_terminated(slice: []const u8, allocator: std.mem.Allocator) ![:0]u8 {
    var result: [:0]u8 = try allocator.allocSentinel(u8, slice.len, 0);
    for (slice, 0..slice.len) |x, idx| {
        result[idx] = x;
    }
    return result;
}
