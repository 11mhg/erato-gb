const zgui = @import("zgui");

pub fn ImColor(r: u8, g: u8, b: u8, a: u8) u32 {
    const r_float: f32 = @as(f32, @floatFromInt(r)) / 255;
    const g_float: f32 = @as(f32, @floatFromInt(g)) / 255;
    const b_float: f32 = @as(f32, @floatFromInt(b)) / 255;
    const a_float: f32 = @as(f32, @floatFromInt(a)) / 255;
    return zgui.colorConvertFloat4ToU32(.{ r_float, b_float, g_float, a_float });
}

pub const tile_colors: [4]u32 = [4]u32{
    0xFFFFFFFF, // White
    0xFFAAAAAA, // Grey
    0xFF555555, // Less Grey
    0xFF000000, // Black
};

pub const tile_colors_enum = enum(u32) {
    white = 0xFFFFFFFF,
    grey = 0xFFAAAAAA,
    dark_grey = 0xFF555555,
    black = 0xFF000000,
};
