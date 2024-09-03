const std = @import("std");
const game_allocator = @import("game_allocator.zig");
const game_errors = @import("game_errors.zig");
const game_emu = @import("game_emu.zig");
const game_cpu = @import("game_cpu.zig");

pub const Timer = struct {
    allocator: std.mem.Allocator,
    emu: *game_emu.Emu,
    div: u16,
    tima: u8,
    tma: u8,
    tac: u8,

    pub fn init(emu: *game_emu.Emu) !*Timer {
        const allocator = game_allocator.GetAllocator();

        const timer = try allocator.create(Timer);
        timer.allocator = allocator;
        timer.emu = emu;
        timer.div = 0xAC00;
        timer.tima = 0;
        timer.tma = 0;
        timer.tac = 0;

        return timer;
    }

    pub fn destroy(self: *Timer) void {
        self.allocator.destroy(self);
    }

    pub fn tick(self: *Timer) void {
        const prev_div: u16 = self.div;

        self.div = @addWithOverflow(self.div, 1)[0];
        var update_timer: bool = false;

        const tac_check: u2 = @truncate(self.tac & 0b11);

        //std.debug.print("tac_check: {b:0>2} - prev_div: {X:0>4} div: {X:0>2}\n", .{ tac_check, prev_div, self.div });

        switch (tac_check) {
            0b00 => {
                const prev_div_bit = (prev_div & (1 << 9));
                const cur_div_bit = (self.div & (1 << 9));
                update_timer = (prev_div_bit != 0) and !(cur_div_bit != 0);
            },
            0b01 => {
                const prev_div_bit = (prev_div & (1 << 3));
                const cur_div_bit = (self.div & (1 << 3));
                update_timer = (prev_div_bit != 0) and !(cur_div_bit != 0);
            },
            0b10 => {
                const prev_div_bit = (prev_div & (1 << 5));
                const cur_div_bit = (self.div & (1 << 5));
                update_timer = (prev_div_bit != 0) and !(cur_div_bit != 0);
            },
            0b11 => {
                const prev_div_bit = (prev_div & (1 << 7));
                const cur_div_bit = (self.div & (1 << 7));
                update_timer = (prev_div_bit != 0) and !(cur_div_bit != 0);
            },
        }

        if (update_timer and ((self.tac & (1 << 2)) != 0)) {
            self.tima += 1;

            if (self.tima == 0xFF) {
                self.tima = self.tma;
                self.emu.cpu.?.request_interrupt(game_cpu.InterruptTypes.TIMER);
            }
        }
    }

    pub fn read(self: *Timer, address: u16) !u8 {
        return switch (address) {
            0xFF04 => @as(u8, @truncate(self.div >> 8)),
            0xFF05 => self.tima,
            0xFF06 => self.tma,
            0xFF07 => self.tac,
            else => {
                std.debug.print("Timer should not have gotten a read for address 0x{X:0>4}\n", .{address});
                return game_errors.EmuErrors.UnexpectedBehavior;
            },
        };
    }

    pub fn write(self: *Timer, address: u16, value: u8) !void {
        switch (address) {
            0xFF04 => {
                self.div = 0;
            },
            0xFF05 => {
                self.tima = value;
            },
            0xFF06 => {
                self.tma = value;
            },
            0xFF07 => {
                self.tac = value;
            },
            else => {
                std.debug.print("Timer should not have gotten write for address 0x{X:0>4} with value 0x{X:0>2}\n", .{ address, value });
                return game_errors.EmuErrors.UnexpectedBehavior;
            },
        }
    }
};
