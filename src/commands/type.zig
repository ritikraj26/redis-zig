const Command = @import("../resp/parser.zig").Command;
const Store = @import("../store/store.zig").Store;
const List = @import("../store/store.zig").List;
const writer = @import("../resp/writer.zig");

pub fn handle(cmd: Command, out: []u8, store: *Store, list: *List) ?[]const u8 {
    _ = out;
    if (cmd.args_len != 1) return writer.err_args;

    const key = cmd.args[0];
    if (store.hasKey(key)) return "+string\r\n";
    if (list.hasKey(key)) return "+list\r\n";
    return "+none\r\n";
}
