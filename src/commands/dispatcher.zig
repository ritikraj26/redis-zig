const std = @import("std");
const parser = @import("../resp/parser.zig");
const writer = @import("../resp/writer.zig");
const Store = @import("../store/store.zig").Store;
const ping = @import("ping.zig");
const echo = @import("echo.zig");
const set = @import("set.zig");
const get = @import("get.zig");

pub fn dispatch(data: []const u8, out: []u8, store: *Store) ?[]const u8 {
    const cmd = parser.parse(data) orelse return null;

    if (std.ascii.eqlIgnoreCase(cmd.name, "ping")) {
        return ping.handle(cmd, out, store);
    } else if (std.ascii.eqlIgnoreCase(cmd.name, "echo")) {
        return echo.handle(cmd, out, store);
    } else if (std.ascii.eqlIgnoreCase(cmd.name, "set")) {
        return set.handle(cmd, out, store);
    } else if (std.ascii.eqlIgnoreCase(cmd.name, "get")) {
        return get.handle(cmd, out, store);
    }

    return writer.err_unknown;
}
