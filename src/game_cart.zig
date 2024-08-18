const std = @import("std");
const game_allocator = @import("game_allocator.zig");
const game_errors = @import("game_errors.zig");

pub const Header = extern struct {
    entry: [4]u8 align(4), // 0100 - 0103
    logo: [48]u8 align(4), // 0104 - 0133
    title: [16]u8 align(4), //0134 - 0143

    lic_code: u16 align(2), //0144-0145
    sgb_flag: u8 align(1), //0146
    cart_type: u8 align(1), // 0147
    rom_size: u8 align(1), //0148
    ram_size: u8 align(1), //0149
    dest_code: u8 align(1), //014A
    old_lic_code: u8 align(1), //014B
    version_number: u8 align(1), //014C
    checksum: u8 align(1), //014D
    global_checksum: u16 align(2), //014E-014F
};

pub const Cart = struct {
    allocator: std.mem.Allocator,
    data: []u8,
    header: *Header,
    rom_size_map: []const usize,
    ram_size_map: []const usize,
    lic_code_map: std.StaticStringMap([]const u8),
    cart_type_map: std.AutoHashMap(u8, []const u8),
    old_lic_code_map: std.AutoHashMap(u8, []const u8),

    pub fn read(self: *Cart, address: u16) !u8 {
        return self.data[address];
    }

    pub fn write(self: *Cart, address: u16, value: u8) !void {
        self.data[address] = value;
    }

    pub fn get_rom_size(self: *Cart) usize {
        return self.rom_size_map[self.header.rom_size];
    }

    pub fn get_ram_size(self: *Cart) usize {
        return self.ram_size_map[self.header.ram_size];
    }

    pub fn get_cart_type(self: *Cart) []const u8 {
        return self.cart_type_map.get(self.header.cart_type) orelse "UNKNOWN";
    }

    pub fn get_lic(self: *Cart) []const u8 {
        const lic_code = [2]u8{
            @truncate(self.header.lic_code >> 8),
            @truncate(self.header.lic_code),
        };
        if (self.lic_code_map.get(&lic_code)) |lic| {
            return lic;
        }
        if (self.old_lic_code_map.get(self.header.old_lic_code)) |lic| {
            return lic;
        }
        return "UNKNOWN";
    }

    pub fn init() !*Cart {
        const allocator: std.mem.Allocator = game_allocator.GetAllocator();
        const cart: *Cart = try allocator.create(Cart);
        cart.allocator = allocator;
        cart.rom_size_map = &rom_size_map;
        cart.ram_size_map = &ram_size_map;
        cart.lic_code_map = lic_code_map;
        cart.cart_type_map = std.AutoHashMap(u8, []const u8).init(allocator);
        cart.old_lic_code_map = std.AutoHashMap(u8, []const u8).init(allocator);
        try make_cart_type_map(&cart.cart_type_map);
        try make_old_lic_map(&cart.old_lic_code_map);
        return cart;
    }

    pub fn read_cart(self: *Cart, filepath: []const u8) !void {
        const cwd_path = try std.fs.cwd().realpathAlloc(self.allocator, ".");
        defer self.allocator.free(cwd_path);

        const absolute_path = try std.fs.path.resolve(self.allocator, &.{
            cwd_path,
            filepath,
        });
        defer self.allocator.free(absolute_path);

        const file = try std.fs.openFileAbsolute(absolute_path, .{ .mode = std.fs.File.OpenMode.read_only });
        defer file.close();

        const file_stat = try file.stat();
        const data: []u8 = try file.readToEndAlloc(self.allocator, file_stat.size);

        const header: *Header = @constCast(@ptrCast(@alignCast(data.ptr + 0x100)));

        self.data = data;
        self.header = header;

        std.log.info("Cartridge Loaded:", .{});
        std.log.info("\t Title   : {s}", .{self.header.title});
        std.log.info("\t Type    : {s}", .{self.get_cart_type()});
        std.log.info("\t ROM size: {d}", .{self.get_rom_size()});
        std.log.info("\t RAM size: {d}", .{self.get_ram_size()});
        std.log.info("\t LIC Code: {s}", .{self.get_lic()});
        std.log.info("\t ROM Vers: 0x{X:0>2}", .{self.header.version_number});

        var checksum: u8 = 0;
        var address: u16 = 0x0134;
        while (address <= 0x014C) : (address += 1) {
            const val = @subWithOverflow(checksum, self.data[address]);
            checksum = @subWithOverflow(val[0], 1)[0];
        }
        std.log.info("\t Checksum: 0x{X:0>2} == 0x{X:0>2} ({s})", .{
            checksum,
            self.header.checksum,
            if (checksum == self.header.checksum) "Success" else "Failed",
        });

        if (checksum != self.header.checksum) {
            std.log.debug("Error! Invalid checksum... something is wrong with this rom.", .{});
            return game_errors.EmuErrors.InvalidChecksumError;
        }
    }

    pub fn destroy(self: *Cart) void {
        self.cart_type_map.deinit();
        self.old_lic_code_map.deinit();
        self.allocator.free(self.data);
        self.allocator.destroy(self);
    }
};

// TESTS

test "Test Cartridge reader" {
    const cart = try Cart.init();
    try cart.read_cart("./roms/dmg-acid2.gb");
    try std.testing.expectEqual(0x00, cart.header.rom_size);
    try std.testing.expect(std.mem.eql(u8, "DMG-ACID", cart.header.title[0..8]));
    try std.testing.expectEqual(cart.data.len, rom_size_map[cart.header.rom_size]);
    try std.testing.expect(cart.data.len > 0);
    try std.testing.expect(std.mem.eql(u8, "None", cart.old_lic_code_map.get(cart.header.old_lic_code) orelse "Failed"));

    var checksum: u8 = 0;
    var address: u16 = 0x0134;
    while (address <= 0x014C) : (address += 1) {
        const val = @subWithOverflow(checksum, cart.data[address]);
        checksum = @subWithOverflow(val[0], 1)[0];
    }
    try std.testing.expectEqual(checksum, cart.header.checksum);
}

// END TESTS

const rom_size_map = [_]usize{
    32768, //32 KiB
    32768 * (1 << 1), //64 KiB
    32768 * (1 << 2), //128 KiB
    32768 * (1 << 3), //256 KiB
    32768 * (1 << 4), //512 KiB
    32768 * (1 << 5), //1 MiB
    32768 * (1 << 6), //2 MiB
    32768 * (1 << 7), //4 MiB
    32768 * (1 << 8), //8 MiB
    (32768 * (1 << 5)) + 104858, // 1.1MiB
    (32768 * (1 << 5)) + (104858 * 2), // 1.2MiB
    (32768 * (1 << 5)) + (32768 * (1 << 4)), // 1.5MiB
};

const ram_size_map = [_]usize{
    0,
    0, // Not Used
    8192, // 8 KiB
    32768, // 32 KiB
    32768 * (1 << 2), // 128 KiB
    32768 * (1 << 1), // 64 KiB
};

const dest_code_map = [_][]const u8{
    "Japan",
    "Overseas",
};

const lic_code_map = std.StaticStringMap([]const u8).initComptime(.{
    .{ "00", "None" },
    .{ "01", "Nintendo Research & Development 1" },
    .{ "08", "Capcom" },
    .{ "13", "EA (Electronic Arts)" },
    .{ "18", "Hudson Soft" },
    .{ "19", "B-AI" },
    .{ "20", "KSS" },
    .{ "22", "Planning Office WADA" },
    .{ "24", "PCM Complete" },
    .{ "25", "San-X" },
    .{ "28", "Kemco" },
    .{ "29", "SETA Corporation" },
    .{ "30", "Viacom" },
    .{ "31", "Nintendo" },
    .{ "32", "Bandai" },
    .{ "33", "Ocean Software/Acclaim Entertainment" },
    .{ "34", "Konami" },
    .{ "35", "HectorSoft" },
    .{ "37", "Taito" },
    .{ "38", "Hudson Soft" },
    .{ "39", "Banpresto" },
    .{ "41", "Ubi Soft1" },
    .{ "42", "Atlus" },
    .{ "44", "Malibu Interactive" },
    .{ "46", "Angel" },
    .{ "47", "Bullet-Proof Software2" },
    .{ "49", "Irem" },
    .{ "50", "Absolute" },
    .{ "51", "Acclaim Entertainment" },
    .{ "52", "Activision" },
    .{ "53", "Sammy USA Corporation" },
    .{ "54", "Konami" },
    .{ "55", "Hi Tech Expressions" },
    .{ "56", "LJN" },
    .{ "57", "Matchbox" },
    .{ "58", "Mattel" },
    .{ "59", "Milton Bradley Company" },
    .{ "60", "Titus Interactive" },
    .{ "61", "Virgin Games Ltd.3" },
    .{ "64", "Lucasfilm Games4" },
    .{ "67", "Ocean Software" },
    .{ "69", "EA (Electronic Arts)" },
    .{ "70", "Infogrames5" },
    .{ "71", "Interplay Entertainment" },
    .{ "72", "Broderbund" },
    .{ "73", "Sculptured Software6" },
    .{ "75", "The Sales Curve Limited7" },
    .{ "78", "THQ" },
    .{ "79", "Accolade" },
    .{ "80", "Misawa Entertainment" },
    .{ "83", "lozc" },
    .{ "86", "Tokuma Shoten" },
    .{ "87", "Tsukuda Original" },
    .{ "91", "Chunsoft Co.8" },
    .{ "92", "Video System" },
    .{ "93", "Ocean Software/Acclaim Entertainment" },
    .{ "95", "Varie" },
    .{ "96", "Yonezawa/s’pal" },
    .{ "97", "Kaneko" },
    .{ "99", "Pack-In-Video" },
    .{ "9H", "Bottom Up" },
    .{ "A4", "Konami (Yu-Gi-Oh!)" },
    .{ "BL", "MTO" },
    .{ "DK", "Kodansha" },
});

fn make_old_lic_map(map: *std.AutoHashMap(u8, []const u8)) !void {
    try map.put(0x00, "None");
    try map.put(0x01, "Nintendo");
    try map.put(0x08, "Capcom");
    try map.put(0x09, "HOT-B");
    try map.put(0x0A, "Jaleco");
    try map.put(0x0B, "Coconuts Japan");
    try map.put(0x0C, "Elite Systems");
    try map.put(0x13, "EA (Electronic Arts)");
    try map.put(0x18, "Hudson Soft");
    try map.put(0x19, "ITC Entertainment");
    try map.put(0x1A, "Yanoman");
    try map.put(0x1D, "Japan Clary");
    try map.put(0x1F, "Virgin Games Ltd.3");
    try map.put(0x24, "PCM Complete");
    try map.put(0x25, "San-X");
    try map.put(0x28, "Kemco");
    try map.put(0x29, "SETA Corporation");
    try map.put(0x30, "Infogrames5");
    try map.put(0x31, "Nintendo");
    try map.put(0x32, "Bandai");
    try map.put(0x33, "Indicates that the New licensee code should be used instead.");
    try map.put(0x34, "Konami");
    try map.put(0x35, "HectorSoft");
    try map.put(0x38, "Capcom");
    try map.put(0x39, "Banpresto");
    try map.put(0x3C, ".Entertainment i");
    try map.put(0x3E, "Gremlin");
    try map.put(0x41, "Ubi Soft1");
    try map.put(0x42, "Atlus");
    try map.put(0x44, "Malibu Interactive");
    try map.put(0x46, "Angel");
    try map.put(0x47, "Spectrum Holoby");
    try map.put(0x49, "Irem");
    try map.put(0x4A, "Virgin Games Ltd.3");
    try map.put(0x4D, "Malibu Interactive");
    try map.put(0x4F, "U.S. Gold");
    try map.put(0x50, "Absolute");
    try map.put(0x51, "Acclaim Entertainment");
    try map.put(0x52, "Activision");
    try map.put(0x53, "Sammy USA Corporation");
    try map.put(0x54, "GameTek");
    try map.put(0x55, "Park Place");
    try map.put(0x56, "LJN");
    try map.put(0x57, "Matchbox");
    try map.put(0x59, "Milton Bradley Company");
    try map.put(0x5A, "Mindscape");
    try map.put(0x5B, "Romstar");
    try map.put(0x5C, "Naxat Soft13");
    try map.put(0x5D, "Tradewest");
    try map.put(0x60, "Titus Interactive");
    try map.put(0x61, "Virgin Games Ltd.3");
    try map.put(0x67, "Ocean Software");
    try map.put(0x69, "EA (Electronic Arts)");
    try map.put(0x6E, "Elite Systems");
    try map.put(0x6F, "Electro Brain");
    try map.put(0x70, "Infogrames5");
    try map.put(0x71, "Interplay Entertainment");
    try map.put(0x72, "Broderbund");
    try map.put(0x73, "Sculptured Software6");
    try map.put(0x75, "The Sales Curve Limited7");
    try map.put(0x78, "THQ");
    try map.put(0x79, "Accolade");
    try map.put(0x7A, "Triffix Entertainment");
    try map.put(0x7C, "Microprose");
    try map.put(0x7F, "Kemco");
    try map.put(0x80, "Misawa Entertainment");
    try map.put(0x83, "Lozc");
    try map.put(0x86, "Tokuma Shoten");
    try map.put(0x8B, "Bullet-Proof Software2");
    try map.put(0x8C, "Vic Tokai");
    try map.put(0x8E, "Ape");
    try map.put(0x8F, "I’Max");
    try map.put(0x91, "Chunsoft Co.8");
    try map.put(0x92, "Video System");
    try map.put(0x93, "Tsubaraya Productions");
    try map.put(0x95, "Varie");
    try map.put(0x96, "Yonezawa/S’Pal");
    try map.put(0x97, "Kemco");
    try map.put(0x99, "Arc");
    try map.put(0x9A, "Nihon Bussan");
    try map.put(0x9B, "Tecmo");
    try map.put(0x9C, "Imagineer");
    try map.put(0x9D, "Banpresto");
    try map.put(0x9F, "Nova");
    try map.put(0xA1, "Hori Electric");
    try map.put(0xA2, "Bandai");
    try map.put(0xA4, "Konami");
    try map.put(0xA6, "Kawada");
    try map.put(0xA7, "Takara");
    try map.put(0xA9, "Technos Japan");
    try map.put(0xAA, "Broderbund");
    try map.put(0xAC, "Toei Animation");
    try map.put(0xAD, "Toho");
    try map.put(0xAF, "Namco");
    try map.put(0xB0, "Acclaim Entertainment");
    try map.put(0xB1, "ASCII Corporation or Nexsoft");
    try map.put(0xB2, "Bandai");
    try map.put(0xB4, "Square Enix");
    try map.put(0xB6, "HAL Laboratory");
    try map.put(0xB7, "SNK");
    try map.put(0xB9, "Pony Canyon");
    try map.put(0xBA, "Culture Brain");
    try map.put(0xBB, "Sunsoft");
    try map.put(0xBD, "Sony Imagesoft");
    try map.put(0xBF, "Sammy Corporation");
    try map.put(0xC0, "Taito");
    try map.put(0xC2, "Kemco");
    try map.put(0xC3, "Square");
    try map.put(0xC4, "Tokuma Shoten");
    try map.put(0xC5, "Data East");
    try map.put(0xC6, "Tonkinhouse");
    try map.put(0xC8, "Koei");
    try map.put(0xC9, "UFL");
    try map.put(0xCA, "Ultra");
    try map.put(0xCB, "Vap");
    try map.put(0xCC, "Use Corporation");
    try map.put(0xCD, "Meldac");
    try map.put(0xCE, "Pony Canyon");
    try map.put(0xCF, "Angel");
    try map.put(0xD0, "Taito");
    try map.put(0xD1, "Sofel");
    try map.put(0xD2, "Quest");
    try map.put(0xD3, "Sigma Enterprises");
    try map.put(0xD4, "ASK Kodansha Co.");
    try map.put(0xD6, "Naxat Soft13");
    try map.put(0xD7, "Copya System");
    try map.put(0xD9, "Banpresto");
    try map.put(0xDA, "Tomy");
    try map.put(0xDB, "LJN");
    try map.put(0xDD, "NCS");
    try map.put(0xDE, "Human");
    try map.put(0xDF, "Altron");
    try map.put(0xE0, "Jaleco");
    try map.put(0xE1, "Towa Chiki");
    try map.put(0xE2, "Yutaka");
    try map.put(0xE3, "Varie");
    try map.put(0xE5, "Epcoh");
    try map.put(0xE7, "Athena");
    try map.put(0xE8, "Asmik Ace Entertainment");
    try map.put(0xE9, "Natsume");
    try map.put(0xEA, "King Records");
    try map.put(0xEB, "Atlus");
    try map.put(0xEC, "Epic/Sony Records");
    try map.put(0xEE, "IGS");
    try map.put(0xF0, "A Wave");
    try map.put(0xF3, "Extreme Entertainment");
    try map.put(0xFF, "LJN");
}

fn make_cart_type_map(map: *std.AutoHashMap(u8, []const u8)) !void {
    try map.put(0x00, "ROM ONLY");
    try map.put(0x01, "MBC1");
    try map.put(0x02, "MBC1+RAM");
    try map.put(0x03, "MBC1+RAM+BATTERY");
    try map.put(0x05, "MBC2");
    try map.put(0x06, "MBC2+BATTERY");
    try map.put(0x08, "ROM+RAM 9");
    try map.put(0x09, "ROM+RAM+BATTERY 9");
    try map.put(0x0B, "MMM01");
    try map.put(0x0C, "MMM01+RAM");
    try map.put(0x0D, "MMM01+RAM+BATTERY");
    try map.put(0x0F, "MBC3+TIMER+BATTERY");
    try map.put(0x10, "MBC3+TIMER+RAM+BATTERY 10");
    try map.put(0x11, "MBC3");
    try map.put(0x12, "MBC3+RAM 10");
    try map.put(0x13, "MBC3+RAM+BATTERY 10");
    try map.put(0x19, "MBC5");
    try map.put(0x1A, "MBC5+RAM");
    try map.put(0x1B, "MBC5+RAM+BATTERY");
    try map.put(0x1C, "MBC5+RUMBLE");
    try map.put(0x1D, "MBC5+RUMBLE+RAM");
    try map.put(0x1E, "MBC5+RUMBLE+RAM+BATTERY");
    try map.put(0x20, "MBC6");
    try map.put(0x22, "MBC7+SENSOR+RUMBLE+RAM+BATTERY");
    try map.put(0xFC, "POCKET CAMERA");
    try map.put(0xFD, "BANDAI TAMA5");
    try map.put(0xFE, "HuC3");
    try map.put(0xFF, "HuC1+RAM+BATTERY");
}
