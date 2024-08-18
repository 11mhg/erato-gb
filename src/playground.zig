const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator: std.mem.Allocator = gpa.allocator();
var loggingAllocator = std.heap.loggingAllocator(allocator);
const finalAllocator = loggingAllocator.allocator();

fn create_memory(size: usize) ![]u8 {
    const memory: []u8 = try finalAllocator.alloc(u8, size);
    return memory;
}

fn greet() !void {
    const memory = try create_memory(100);
    defer finalAllocator.free(memory);
    std.debug.print("Test!\n", .{});
}

pub fn main() !void {
    try greet();
    defer std.debug.assert(gpa.deinit() == .ok);
}
