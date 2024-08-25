const std = @import("std");
const zgui = @import("zgui");

pub fn open() []const u8 {
    if (zgui.begin("FileDialog", .{})) {
        zgui.end();
    }
    return "temp";
}
