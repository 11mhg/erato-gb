const std = @import("std");
const game_errors = @import("game_errors.zig");
const game_allocator = @import("game_allocator.zig");
const game_timer = @import("game_timer.zig");
const game_emu = @import("game_emu.zig");

pub const IO = struct {
    allocator: std.mem.Allocator,
    serial_data: []u8,
    timer: *game_timer.Timer,
    emu: *game_emu.Emu,
    ly: u8,

    pub fn init(emu: *game_emu.Emu, timer: *game_timer.Timer) !*IO {
        const allocator = game_allocator.GetAllocator();
        const io = try allocator.create(IO);

        io.allocator = allocator;
        io.serial_data = try allocator.alloc(u8, 2);
        io.timer = timer;
        io.emu = emu;
        io.ly = 0;
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
            0xFF04...0xFF07 => {
                return try self.timer.read(address);
            },
            0xFF0F => {
                return self.emu.cpu.?.int_flags;
            },
            0xFF40...0xFF4B => {
                return self.emu.lcd.?.read(address);
            },
            else => {
                std.debug.print("[I/O] - Unsupported bus read 0x{X:0>4}\n", .{address});
                return 0;
            },
        }
    }

    pub fn write(self: *IO, address: u16, value: u8) !void {
        switch (address) {
            0xFF01 => {
                self.serial_data[0] = value;
            },
            0xFF02 => {
                self.serial_data[1] = value;
            },
            0xFF04...0xFF07 => {
                try self.timer.write(address, value);
            },
            0xFF0F => {
                self.emu.cpu.?.int_flags = value;
            },
            0xFF40...0xFF4B => {
                return self.emu.lcd.?.write(address, value);
            },
            else => {
                std.debug.print("[I/O] - Unsupported bus write 0x{X:0>4} (0x{X:0>2})\n", .{ address, value });
            },
        }
    }
};
