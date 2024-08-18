const std = @import("std");

pub fn sleep(sec: f32) void {
    const time: u64 = @intFromFloat(sec * std.time.ns_per_s);
    std.time.sleep(time);
}
