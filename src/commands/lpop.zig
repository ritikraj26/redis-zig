const std = @import("std");
const Command = @import("../resp/parser.zig").Command;
const Store = @import("../store/store.zig").Store;
const List = @import("../store/store.zig").List;
const writer = @import("../resp/writer.zig");

pub fn handle(cmd: Command, out: []u8, store: *Store, list: *List) ?[]const u8 {
    _ = store;
    if (cmd.args_len < 1) return writer.err_args;

    // Optional count argument
    if (cmd.args_len >= 2) {
        const count = std.fmt.parseInt(usize, cmd.args[1], 10) catch return writer.err_parse;
        var buf: [512][]const u8 = undefined;
        const n = list.lpopN(cmd.args[0], buf[0..@min(count, buf.len)]);
        if (n == 0) return writer.nil;
        return writer.array(out, buf[0..n]);
    }

    const val = list.lpop(cmd.args[0]) orelse return writer.nil;
    return writer.bulkString(out, val);
}
