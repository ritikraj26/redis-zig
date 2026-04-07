const Command = @import("../resp/parser.zig").Command;
const Store = @import("../store/store.zig").Store;
const writer = @import("../resp/writer.zig");

pub fn handle(cmd: Command, out: []u8, store: *Store) ?[]const u8 {
    _ = out;
    if (cmd.args_len < 2) return writer.err_args;
    store.set(cmd.args[0], cmd.args[1]) catch return null;
    return writer.ok;
}
