const std = @import("std");
const Command = @import("../resp/parser.zig").Command;
const Store = @import("../store/store.zig").Store;
const List = @import("../store/store.zig").List;
const writer = @import("../resp/writer.zig");

pub fn handle(cmd: Command, out: []u8, store: *Store, list: *List) ?[]const u8 {
    _ = store;
    if (cmd.args_len < 3) return writer.err_args;
    const start = std.fmt.parseInt(i64, cmd.args[1], 10) catch return writer.err_args;
    const end = std.fmt.parseInt(i64, cmd.args[2], 10) catch return writer.err_args;
    const items = list.lrange(cmd.args[0], start, end) orelse return writer.emptyArray;
    if (items.len == 0) return writer.emptyArray;
    return writer.array(out, items);
}
