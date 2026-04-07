const std = @import("std");
const Command = @import("../resp/parser.zig").Command;
const Store = @import("../store/store.zig").Store;
const writer = @import("../resp/writer.zig");

pub fn handle(cmd: Command, out: []u8, store: *Store) ?[]const u8 {
    _ = out;
    if (cmd.args_len < 2) return writer.err_args;
    if (cmd.args_len > 2) {
        if (std.mem.eql(u8, cmd.args[2], "EX")) {
            const ttl = std.fmt.parseInt(u64, cmd.args[3], 10) catch return writer.err_args;
            store.setWithTTL(cmd.args[0], cmd.args[1], ttl * 1000) catch return null;
        } else if (std.mem.eql(u8, cmd.args[2], "PX")) {
            const ttl = std.fmt.parseInt(u64, cmd.args[3], 10) catch return writer.err_args;
            store.setWithTTL(cmd.args[0], cmd.args[1], ttl) catch return null;
        } else {
            return writer.err_args;
        }
    } else {
        store.set(cmd.args[0], cmd.args[1]) catch return null;
    }
    return writer.ok;
}
