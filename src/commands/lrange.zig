const std = @import("std");
const Command = @import("../resp/parser.zig").Command;
const Store = @import("../store/store.zig").Store;
const List = @import("../store/store.zig").List;
const writer = @import("../resp/writer.zig");

pub fn handle(cmd: Command, out: []u8, store: *Store, list: *List) ?[]const u8 {
    _ = store;
    if (cmd.args_len < 3) return writer.err_args;

    const key = cmd.args[0];
    const start = std.fmt.parseInt(i64, cmd.args[1], 10) catch return writer.err_args;
    const end = std.fmt.parseInt(i64, cmd.args[2], 10) catch return writer.err_args;

    list.mutex.lock();
    defer list.mutex.unlock();

    const items = if (list.map.get(key)) |l| l.items else return writer.emptyArray;

    const len = @as(i64, @intCast(items.len));

    const s = if (start < 0) @max(len + start, 0) else @min(start, len);
    const e = if (end < 0) len + end + 1 else @min(end + 1, len);

    if (s >= e) return writer.emptyArray;

    return writer.array(out, items[@intCast(s)..@intCast(e)]);
}
