const std = @import("std");
const stdout = std.fs.File.stdout();
const net = std.net;

fn handleConnection(connection: net.Server.Connection) void {
    defer connection.stream.close();

    var buf: [1024]u8 = undefined;
    while (true) {
        const n = connection.stream.read(&buf) catch break;
        if (n == 0) break;
        connection.stream.writeAll("+PONG\r\n") catch break;
    }
}

pub fn main() !void {
    const address = try net.Address.resolveIp("127.0.0.1", 6379);

    var listener = try address.listen(.{
        .reuse_address = true,
    });
    defer listener.deinit();

    while (true) {
        const connection = try listener.accept();

        try stdout.writeAll("accepted new connection");

        const thread = try std.Thread.spawn(.{}, handleConnection, .{connection});
        thread.detach();
    }
}
