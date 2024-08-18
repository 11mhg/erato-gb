const std = @import("std");

const AssetNotFoundError = error{BootRomNotFoundError};

pub fn GetBootRoom(boot_rom_name: []const u8) ![]const u8 {
    const cgb_boot_rom: []const u8 = @embedFile("assets/bootroms/cgb_boot.bin");
    const dmg_boot_rom: []const u8 = @embedFile("assets/bootroms/dmg_boot.bin");
    if (std.mem.eql(u8, "cgb", boot_rom_name)) {
        return cgb_boot_rom;
    } else if (std.mem.eql(u8, "dmg", boot_rom_name)) {
        return dmg_boot_rom;
    }
    return AssetNotFoundError.BootRomNotFoundError;
}

// Tests

test "Test Get Boot Rom Asset" {
    const boot_rom = try GetBootRoom("dmg");
    try std.testing.expectEqual(256, boot_rom.len);
}
