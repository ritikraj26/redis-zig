const std = @import("std");
const Command = @import("../resp/parser.zig").Command;
const Store = @import("../store/store.zig").Store;
const List = @import("../store/store.zig").List;
const writer = @import("../resp/writer.zig");

pub fn handle(cmd: Command, out: []u8, store: *Store, list: *List) ?[]const u8 {
    _ = store;
    // Need at least one key + the timeout arg.
    if (cmd.args_len < 2) return writer.err_args;

    const timeout_str = cmd.args[cmd.args_len - 1];
    const timeout_secs = std.fmt.parseFloat(f64, timeout_str) catch return writer.err_parse;
    const timeout_ms: u64 = if (timeout_secs <= 0) 0 else @intFromFloat(timeout_secs * 1000.0);

    const keys: []const []const u8 = cmd.args[0..cmd.args_len - 1];

    const result = list.blpop(keys, timeout_ms) orelse return writer.nil_array;
    const items = [2][]const u8{ result[0], result[1] };
    return writer.array(out, &items);
}
