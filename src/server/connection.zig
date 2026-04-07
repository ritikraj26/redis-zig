const std = @import("std");
const net = std.net;
const dispatcher = @import("../commands/dispatcher.zig");
const Store = @import("../store/store.zig").Store;
const writer = @import("../resp/writer.zig");

pub const ConnArgs = struct {
    conn: net.Server.Connection,
    store: *Store,
};

pub fn handle(args: ConnArgs) void {
    defer args.conn.stream.close();

    var buf: [1024]u8 = undefined;
    var resp_buf: [1024]u8 = undefined;

    while (true) {
        const n = args.conn.stream.read(&buf) catch break;
        if (n == 0) break;
        const response = dispatcher.dispatch(buf[0..n], &resp_buf, args.store) orelse writer.err_parse;
        args.conn.stream.writeAll(response) catch break;
    }
}
