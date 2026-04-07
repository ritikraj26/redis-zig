const std = @import("std");
const net = std.net;
const Store = @import("../store/store.zig").Store;
const connection = @import("connection.zig");

const stdout = std.fs.File.stdout();

pub fn run(store: *Store) !void {
    const address = try net.Address.resolveIp("127.0.0.1", 6379);

    var listener = try address.listen(.{ .reuse_address = true });
    defer listener.deinit();

    while (true) {
        const conn = try listener.accept();
        try stdout.writeAll("accepted new connection");

        const thread = try std.Thread.spawn(.{}, connection.handle, .{connection.ConnArgs{ .conn = conn, .store = store }});
        thread.detach();
    }
}
