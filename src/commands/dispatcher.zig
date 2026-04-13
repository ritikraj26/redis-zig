const std = @import("std");
const parser = @import("../resp/parser.zig");
const writer = @import("../resp/writer.zig");
const Store = @import("../store/store.zig").Store;
const List = @import("../store/store.zig").List;
const ping = @import("ping.zig");
const echo = @import("echo.zig");
const set = @import("set.zig");
const get = @import("get.zig");
const rpush = @import("rpush.zig");
const lpush = @import("lpush.zig");
const lrange = @import("lrange.zig");

pub fn dispatch(data: []const u8, out: []u8, store: *Store, list: *List) ?[]const u8 {
    const cmd = parser.parse(data) orelse return null;

    if (std.ascii.eqlIgnoreCase(cmd.name, "ping")) {
        return ping.handle(cmd, out, store);
    } else if (std.ascii.eqlIgnoreCase(cmd.name, "echo")) {
        return echo.handle(cmd, out, store);
    } else if (std.ascii.eqlIgnoreCase(cmd.name, "set")) {
        return set.handle(cmd, out, store);
    } else if (std.ascii.eqlIgnoreCase(cmd.name, "get")) {
        return get.handle(cmd, out, store);
    } else if (std.ascii.eqlIgnoreCase(cmd.name, "rpush")) {
        return rpush.handle(cmd, out, store, list);
    } else if (std.ascii.eqlIgnoreCase(cmd.name, "lpush")) {
        return lpush.handle(cmd, out, store, list);
    } else if (std.ascii.eqlIgnoreCase(cmd.name, "lrange")) {
        return lrange.handle(cmd, out, store, list);
    }

    return writer.err_unknown;
}
