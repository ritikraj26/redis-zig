const std = @import("std");
const Command = @import("../resp/parser.zig").Command;
const Store = @import("../store/store.zig").Store;
const List = @import("../store/store.zig").List;
const writer = @import("../resp/writer.zig");

pub fn handle(cmd: Command, out: []u8, store: *Store, list: *List) ?[]const u8 {
    _ = store;
    if (cmd.args_len < 1) return writer.err_args;
    const val = list.lpop(cmd.args[0]) orelse return writer.nil;
    return writer.bulkString(out, val);
}
