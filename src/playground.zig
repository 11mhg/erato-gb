const std = @import("std");

//var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//const allocator: std.mem.Allocator = gpa.allocator();
//var loggingAllocator = std.heap.loggingAllocator(allocator);
//const finalAllocator = loggingAllocator.allocator();
//
//fn create_memory(size: usize) ![]u8 {
//    const memory: []u8 = try finalAllocator.alloc(u8, size);
//    return memory;
//}
//
//fn greet() !void {
//    const memory = try create_memory(100);
//    defer finalAllocator.free(memory);
//    std.debug.print("Test!\n", .{});
//}

pub fn main() !void {
    const value: u8 = 203;
    const carry: u1 = @truncate(value & 0x1);
    const rrca: u8 = value >> 1 | (@as(u8, carry) << 7);

    std.debug.print("0b{b:0>8}\n", .{value});
    std.debug.print("0b{b:0>8}\n", .{carry});
    std.debug.print("0b{b:0>8}\n", .{rrca});
}
