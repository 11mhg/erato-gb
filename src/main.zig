const std = @import("std");
const game_emu = @import("game_emu.zig");
const game_allocator = @import("game_allocator.zig");
const game_utils = @import("game_utils.zig");

pub fn main() !void {
    const allocator = game_allocator.GetAllocator();

    var arg_iterator: std.process.ArgIterator = try std.process.argsWithAllocator(allocator);
    defer arg_iterator.deinit();
    var args = [3]?[]const u8{ null, null, null };

    for (0..3) |iter| {
        args[iter] = arg_iterator.next();
    }

    if (game_utils.check_debug_flag(args[2])) {
        game_utils.DEBUG_MODE = true;
    }

    try game_emu.Emu.run(args[1], null);
}
