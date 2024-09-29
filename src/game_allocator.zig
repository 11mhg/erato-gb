const std = @import("std");
const ztracy = @import("ztracy");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator: std.mem.Allocator = gpa.allocator();
var tracy_gpa = ztracy.TracyAllocator.init(allocator);
const tracy_allocator = tracy_gpa.allocator();

pub fn GetAllocator() std.mem.Allocator {
    return tracy_allocator;
}
