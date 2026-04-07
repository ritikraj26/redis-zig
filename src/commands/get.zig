const Command = @import("../resp/parser.zig").Command;
const Store = @import("../store/store.zig").Store;
const writer = @import("../resp/writer.zig");

pub fn handle(cmd: Command, out: []u8, store: *Store) ?[]const u8 {
    if (cmd.args_len < 1) return writer.err_args;
    if (store.get(cmd.args[0])) |val| {
        return writer.bulkString(out, val);
    } else {
        return writer.nil;
    }
}
