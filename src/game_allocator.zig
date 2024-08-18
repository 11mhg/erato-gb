const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator: std.mem.Allocator = gpa.allocator();

pub fn GetAllocator() std.mem.Allocator {
    return allocator;
}
