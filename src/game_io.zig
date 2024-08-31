const std = @import("std");
const game_errors = @import("game_errors.zig");
const game_allocator = @import("game_allocator.zig");

pub const IO = struct {
    allocator: std.mem.Allocator,
    serial_data: []u8,

    pub fn init() !*IO {
        const allocator = game_allocator.GetAllocator();
        const io = try allocator.create(IO);

        io.allocator = allocator;
        io.serial_data = try allocator.alloc(u8, 2);
        @memset(io.serial_data, 0);

        return io;
    }

    pub fn destroy(self: *IO) void {
        self.allocator.destroy(self);
    }

    pub fn read(self: *IO, address: u16) !u8 {
        switch (address) {
            0xFF01 => {
                return self.serial_data[0];
            },
            0xFF02 => {
                return self.serial_data[1];
            },
            else => {
                std.debug.print("[I/O] - Unsupported bus read 0x{X:0>4}\n", .{address});
                return 0;
            },
        }

        return game_errors.EmuErrors.NotImplementedError;
    }

    pub fn write(self: *IO, address: u16, value: u8) !void {
        switch (address) {
            0xFF01 => {
                self.serial_data[0] = value;
            },
            0xFF02 => {
                self.serial_data[1] = value;
            },
            else => {
                std.debug.print("[I/O] - Unsupported bus write 0x{X:0>4} (0x{X:0>2})\n", .{ address, value });
            },
        }
    }
};
