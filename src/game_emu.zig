const std = @import("std");
const game_allocator = @import("game_allocator.zig");
const game_cart = @import("game_cart.zig");
const game_bus = @import("game_bus.zig");
const game_cpu = @import("game_cpu.zig");
const game_utils = @import("game_utils.zig");
const game_errors = @import("game_errors.zig");
const game_boot_rom = @import("game_boot_rom.zig");

pub const Emu = struct {
    allocator: ?std.mem.Allocator,
    cart: ?*game_cart.Cart,
    memory_bus: ?*game_bus.MemoryBus,
    cpu: ?*game_cpu.CPU,
    boot_rom_name: []const u8,
    boot_rom: ?[]const u8,

    running: bool,
    paused: bool,
    ticks: u64,

    cycle_num: u32,

    pub fn init() !*Emu {
        const allocator = game_allocator.GetAllocator();
        var emu: *Emu = try allocator.create(Emu);
        emu.allocator = game_allocator.GetAllocator();
        emu.cart = null;
        emu.memory_bus = null;
        emu.cpu = null;
        emu.boot_rom_name = "dmg";
        emu.boot_rom = null;
        emu.running = false;
        emu.paused = false;
        emu.ticks = 0;
        emu.cycle_num = 0;
        return emu;
    }

    pub fn cycle(self: *Emu, num_cycles: u32) void {
        //TODO: Update cycles to keep PPU in step with CPU.
        self.cycle_num += num_cycles;
    }

    pub fn prep_emu(self: *Emu, rom_path: []const u8) !void {
        //Initialize game cart
        const cart: *game_cart.Cart = try game_cart.Cart.init();
        try cart.read_cart(rom_path);
        self.cart = cart;

        const boot_rom: []const u8 = try game_boot_rom.GetBootRoom(self.boot_rom_name);
        self.boot_rom = boot_rom;

        const memory_bus: *game_bus.MemoryBus = try game_bus.MemoryBus.init(self);
        self.memory_bus = memory_bus;

        const cpu: *game_cpu.CPU = try game_cpu.CPU.init(self);
        self.cpu = cpu;

        try game_boot_rom.InitializeRegisters(self.cpu.?, self.cart.?, self.boot_rom_name);

        self.memory_bus.?.*.map_boot_rom = false;

        self.running = true;
        self.paused = false;
        self.ticks = 0;
    }

    pub fn run(rom_path: ?[]const u8, boot_rom_name: ?[]const u8) !void {
        const emu = try Emu.init();
        defer emu.destroy();

        if (boot_rom_name) |val| {
            emu.boot_rom_name = val;
        }

        if (rom_path) |val| {
            try emu.run_with_rom(val);
        } else {
            try emu.run_without_rom();
        }
    }

    fn run_without_rom(_: *Emu) !void {}

    fn run_with_rom(self: *Emu, rom_path: []const u8) !void {
        try self.prep_emu(rom_path);

        while (self.running) {
            if (self.paused) {
                game_utils.sleep(0.1);
            }

            const succeeded = try self.cpu.?.*.step();
            if (!succeeded) {
                return game_errors.EmuErrors.StepFailedError;
            }

            self.ticks += 1;
        }
    }

    pub fn destroy(self: *Emu) void {
        if (self.cart) |cart| {
            cart.destroy();
        }
        if (self.memory_bus) |memory_bus| {
            memory_bus.destroy();
        }
        if (self.cpu) |cpu| {
            cpu.destroy();
        }
        if (self.allocator) |alloc| {
            alloc.destroy(self);
        }
    }
};

// TESTS

test "test emu startup" {
    const emu: *Emu = try Emu.init();
    defer emu.destroy();

    if (emu.allocator) |_| {
        try std.testing.expect(true);
    } else {
        try std.testing.expect(false);
    }
}
