const std = @import("std");
const Value = std.json.Value;
const game_allocator = @import("game_allocator.zig");
const game_emu = @import("game_emu.zig");
const game_cpu = @import("game_cpu.zig");
const game_bus = @import("game_bus.zig");
const game_utils = @import("game_utils.zig");

const CPU = struct {
    a: u8,
    b: u8,
    c: u8,
    d: u8,
    e: u8,
    f: u8,
    h: u8,
    l: u8,
    pc: u16,
    sp: u16,
};

const State = struct {
    cpu: CPU,
    ram: [][]u16,
};

const FinalState = struct {
    a: u8,
    b: u8,
    c: u8,
    d: u8,
    e: u8,
    f: u8,
    h: u8,
    l: u8,
    pc: u16,
    sp: u16,
    ram: [][]u16,
};

const Test = struct {
    name: []const u8,
    initial: State,
    final: State,
};

fn parse_ram(arr: []std.json.Value, allocator: std.mem.Allocator) ![][]u16 {
    const return_value: [][]u16 = try allocator.alloc([]u16, arr.len);
    for (arr, 0..) |val, idx| {
        const inner_arr: []std.json.Value = val.array.items;
        return_value[idx] = try allocator.alloc(u16, inner_arr.len);
        for (inner_arr, 0..) |inner_val, inner_idx| {
            return_value[idx][inner_idx] = @intCast(inner_val.integer);
        }
    }
    return return_value;
}

test "sm83" {
    game_utils.DEBUG_MODE = true;

    const allocator = game_allocator.GetAllocator();
    std.debug.print("Beginning sm83 tests!", .{});

    var sm83_test_dir = try std.fs.cwd().openDir("../sm83/v1/", .{ .iterate = true });
    defer sm83_test_dir.close();

    var test_dir_iterator = sm83_test_dir.iterate();
    while (try test_dir_iterator.next()) |file| {
        std.debug.print("Processing: {s}\n", .{file.name});
        const fileHandle = try sm83_test_dir.openFile(file.name, .{});
        defer fileHandle.close();

        const file_text = try fileHandle.readToEndAlloc(allocator, 5000000000);
        defer allocator.free(file_text);

        const parsed = try std.json.parseFromSlice(Value, allocator, file_text, .{});
        defer parsed.deinit();

        const tests = parsed.value;

        for (tests.array.items) |parsed_test| {
            std.debug.print("Running test: {s}\n", .{parsed_test.object.get("name").?.string});
            const _test = try allocator.create(Test);
            defer allocator.destroy(_test);

            _test.name = parsed_test.object.get("name").?.string;

            try parse_state(&_test.initial, parsed_test.object.get("initial").?, allocator);
            defer allocator.free(_test.initial.ram);

            try parse_state(&_test.final, parsed_test.object.get("final").?, allocator);
            defer allocator.free(_test.final.ram);

            const emu = try game_emu.Emu.init();
            defer emu.destroy();

            try emu.prep_emu("./roms/dmg-acid2.gb");

            std.debug.print("PC: {X:0>4}\n", .{emu.cpu.?.registers.pc});
            try set_state(emu.cpu.?, emu.memory_bus.?, &_test.initial);
            std.debug.print("PC: {X:0>4}\n", .{emu.cpu.?.registers.pc});

            const success = try emu.cpu.?.step();
            try std.testing.expect(success);

            check_state(emu.cpu.?, emu.memory_bus.?, &_test.final) catch |e| {
                std.debug.print("CPU register b starts as 0x{X:0>2} and ends as 0x{X:0>2}\n", .{ _test.initial.cpu.b, _test.final.cpu.b });
                return e;
            };
        }
    }
}

fn expect_check(comptime T: type, left: T, right: T) !void {
    std.testing.expect(left == right) catch |e| {
        std.log.err("Got 0x{X:0>2} expected 0x{X:0>2}\n", .{ left, right });
        return e;
    };
}

fn check_state(cpu: *game_cpu.CPU, memory_bus: *game_bus.MemoryBus, state: *State) !void {
    try expect_check(u8, cpu.registers.a, state.cpu.a);
    try expect_check(u8, cpu.registers.b, state.cpu.b);
    try expect_check(u8, cpu.registers.c, state.cpu.c);
    try expect_check(u8, cpu.registers.d, state.cpu.d);
    try expect_check(u8, cpu.registers.e, state.cpu.e);
    try expect_check(u8, cpu.registers.f, state.cpu.f);
    try expect_check(u8, cpu.registers.h, state.cpu.h);
    try expect_check(u8, cpu.registers.l, state.cpu.l);
    try expect_check(u16, cpu.registers.sp, state.cpu.sp);
    try expect_check(u16, cpu.registers.pc, state.cpu.pc);

    for (state.ram) |ram_value| {
        const address: u16 = @intCast(ram_value[0]);
        const value: u8 = @intCast(ram_value[1]);
        const current_value: u8 = try memory_bus.read(address);
        try expect_check(u8, value, current_value);
    }
    return;
}

fn set_state(cpu: *game_cpu.CPU, memory_bus: *game_bus.MemoryBus, state: *State) !void {
    cpu.registers.a = state.cpu.a;
    cpu.registers.b = state.cpu.b;
    cpu.registers.c = state.cpu.c;
    cpu.registers.d = state.cpu.d;
    cpu.registers.e = state.cpu.e;
    cpu.registers.f = state.cpu.f;
    cpu.registers.h = state.cpu.h;
    cpu.registers.l = state.cpu.l;
    cpu.registers.sp = state.cpu.sp;
    cpu.registers.pc = state.cpu.pc;

    for (state.ram) |ram_value| {
        const address: u16 = @intCast(ram_value[0]);
        const value: u8 = @intCast(ram_value[1]);
        std.debug.print("Writing 0x{X:0>2} to address 0x{X:0>4}\n", .{ value, address });
        try memory_bus.write(address, value);
    }
    return;
}

fn parse_state(state: *State, value: Value, allocator: std.mem.Allocator) !void {
    state.cpu.a = @intCast(value.object.get("a").?.integer);
    state.cpu.b = @intCast(value.object.get("b").?.integer);
    state.cpu.c = @intCast(value.object.get("c").?.integer);
    state.cpu.d = @intCast(value.object.get("d").?.integer);
    state.cpu.e = @intCast(value.object.get("e").?.integer);
    state.cpu.f = @intCast(value.object.get("f").?.integer);
    state.cpu.h = @intCast(value.object.get("h").?.integer);
    state.cpu.l = @intCast(value.object.get("l").?.integer);
    state.cpu.pc = @intCast(value.object.get("pc").?.integer);
    state.cpu.sp = @intCast(value.object.get("sp").?.integer);

    state.ram = try parse_ram(value.object.get("ram").?.array.items, allocator);
    return;
}
