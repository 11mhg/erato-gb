const std = @import("std");

const game_allocator = @import("game_allocator.zig");
const game_ui = @import("game_ui.zig");
const game_cart = @import("game_cart.zig");
const game_bus = @import("game_bus.zig");
const game_cpu = @import("game_cpu.zig");
const game_utils = @import("game_utils.zig");
const game_errors = @import("game_errors.zig");
const game_boot_rom = @import("game_boot_rom.zig");
const game_dbg = @import("game_dbg.zig");
const game_timer = @import("game_timer.zig");
const game_ppu = @import("game_ppu.zig");
const ztracy = @import("ztracy");

pub const Emu = struct {
    allocator: ?std.mem.Allocator,
    boot_rom_name: []const u8,
    boot_rom: ?[]const u8,
    cart: ?*game_cart.Cart,
    cpu: ?*game_cpu.CPU,
    dbg: ?*game_dbg.DBG,
    memory_bus: ?*game_bus.MemoryBus,
    ui: ?*game_ui.UI,
    timer: ?*game_timer.Timer,
    ppu: ?*game_ppu.PPU,

    cartridge_loaded: bool,
    running: bool,
    paused: bool,
    ticks: u64,
    debug_counter: u64,
    curr_error: ?game_errors.EmuErrors,

    cycle_num: u32,

    pub fn init() !*Emu {
        const allocator = game_allocator.GetAllocator();
        var emu: *Emu = try allocator.create(Emu);
        emu.allocator = game_allocator.GetAllocator();
        if (!game_utils.is_debug()) {
            emu.ui = try game_ui.UI.init(emu);
        }
        emu.timer = null;
        emu.cart = null;
        emu.dbg = null;
        emu.memory_bus = null;
        emu.cpu = null;
        emu.boot_rom_name = "dmg";
        emu.boot_rom = null;
        emu.running = false;
        emu.paused = false;
        emu.ticks = 0;
        emu.debug_counter = 0;
        emu.cycle_num = 0;
        emu.cartridge_loaded = false;
        emu.curr_error = undefined;
        emu.ppu = null;
        return emu;
    }

    pub fn cycle(self: *Emu, num_cycles: u32) !void {
        //TODO: Update cycles to keep PPU in step with CPU.
        self.cycle_num += num_cycles;
        for (0..(num_cycles)) |_| {
            for (0..4) |_| {
                self.ticks += 1;
                self.timer.?.tick();
            }

            try self.ppu.?.dma.tick();
        }
    }

    pub fn prep_emu(self: *Emu, rom_path: []const u8) !void {
        //Initialize game cart
        const cart: *game_cart.Cart = try game_cart.Cart.init();
        try cart.read_cart(rom_path);
        self.cart = cart;
        self.cartridge_loaded = true;

        const boot_rom: []const u8 = try game_boot_rom.GetBootRoom(self.boot_rom_name);
        self.boot_rom = boot_rom;

        const timer: *game_timer.Timer = try game_timer.Timer.init(self);
        self.timer = timer;

        const ppu: *game_ppu.PPU = try game_ppu.PPU.init(self);
        self.ppu = ppu;

        const memory_bus: *game_bus.MemoryBus = try game_bus.MemoryBus.init(self, self.timer.?, self.ppu.?);
        self.memory_bus = memory_bus;

        const cpu: *game_cpu.CPU = try game_cpu.CPU.init(self);
        self.cpu = cpu;

        const dbg: *game_dbg.DBG = try game_dbg.DBG.init();
        self.dbg = dbg;

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
            try emu.prep_emu(val);
        }

        if (game_utils.is_debug()) {
            try emu.run_debug();
        } else {
            try emu.run_();
        }
    }

    fn run_debug(self: *Emu) !void {
        while (true) {
            const emu_zone = ztracy.ZoneNC(@src(), "Emulator main loop [debug]", 0x00_FF_00_00);
            defer emu_zone.End();
            if (self.running and self.cartridge_loaded) {
                const succeeded = try self.cpu.?.*.step();
                if (!succeeded) {
                    return game_errors.EmuErrors.StepFailedError;
                }
                self.debug_counter += 1;
            }
        }
    }

    fn run_(self: *Emu) !void {
        while (!self.ui.?.window.shouldClose()) {
            const emu_zone = ztracy.ZoneNC(@src(), "Emulator main loop", 0x00_FF_00_00);
            defer emu_zone.End();
            if (self.running and self.cartridge_loaded) {
                const succeeded = try self.cpu.?.*.step();
                if (!succeeded) {
                    return game_errors.EmuErrors.StepFailedError;
                }
                self.debug_counter += 1;
            }
            self.ui.?.pre_render();
            try self.ui.?.render();
            self.ui.?.post_render();
            ztracy.FrameMarkNamed("Main Frame [debug]");
        }
    }

    pub fn destroy(self: *Emu) void {
        if (self.ui) |ui| {
            if (!game_utils.is_debug()) {
                ui.destroy();
            }
        }
        if (self.cart) |cart| {
            cart.destroy();
        }
        if (self.timer) |timer| {
            timer.destroy();
        }
        if (self.memory_bus) |memory_bus| {
            memory_bus.destroy();
        }
        if (self.ppu) |ppu| {
            ppu.destroy();
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
