const std = @import("std");

pub fn sleep(sec: f32) void {
    const time: u64 = @intFromFloat(sec * std.time.ns_per_s);
    std.time.sleep(time);
}

pub var DEBUG_MODE = false;

pub fn is_debug() bool {
    return !!DEBUG_MODE;
}

pub fn check_debug_flag(elem: ?[]const u8) bool {
    if (elem) |el| {
        if (std.mem.eql(u8, el, "-d")) {
            return true;
        }
    }
    return false;
}
