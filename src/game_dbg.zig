const std = @import("std");
const game_allocator = @import("game_allocator.zig");
const game_bus = @import("game_bus.zig");

pub const DBG = struct {
    allocator: std.mem.Allocator,
    dbg_msg: []u8,
    msg_size: usize,

    pub fn init() !*DBG {
        const allocator = game_allocator.GetAllocator();

        const dbg = try allocator.create(DBG);
        dbg.allocator = allocator;
        dbg.dbg_msg = try allocator.alloc(u8, 1024);
        dbg.msg_size = 0;

        return dbg;
    }

    pub fn update(self: *DBG, bus: *game_bus.MemoryBus) !void {
        if (try bus.read(0xFF02) == 0x81) {
            const c: u8 = try bus.read(0xFF01);
            self.dbg_msg[self.msg_size] = c;
            self.msg_size += 1;

            try bus.write(0xFF02, 0);
        }
    }

    pub fn print(self: *DBG) void {
        if (self.msg_size > 0) {
            std.debug.print("DBG Message: {s}\n", .{self.dbg_msg});
        }
    }

    pub fn destroy(self: *DBG) void {
        self.allocator.destroy(self);
    }
};
