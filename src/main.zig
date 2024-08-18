const std = @import("std");
const game_emu = @import("game_emu.zig");
const game_allocator = @import("game_allocator.zig");

pub fn main() !void {
    const allocator = game_allocator.GetAllocator();
    var arg_iterator: std.process.ArgIterator = try std.process.argsWithAllocator(allocator);
    defer arg_iterator.deinit();
    var args = [2]?[]const u8{ null, null };

    for (0..2) |iter| {
        args[iter] = arg_iterator.next();
    }

    try game_emu.Emu.run(args[1]);
}
