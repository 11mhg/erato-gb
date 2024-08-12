const std = @import("std");
const game_allocator = @import("game_allocator.zig");

pub fn CreateMemoryBus() !MemoryBus {
    const allocator = game_allocator.GetAllocator();
    const memory = try allocator.alloc(u8, 8000);
    @memset(memory, 0);
    return MemoryBus{ .memory = memory };
}

pub const MemoryBus = struct {
    memory: []u8,

    fn read_byte(self: *MemoryBus, address: u16) u8 {
        return self.memory[@as(usize, address)];
    }
};
