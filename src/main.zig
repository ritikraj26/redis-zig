const std = @import("std");
const stdout = std.fs.File.stdout();
const net = std.net;

fn parseAndRespond(data: []const u8, out: []u8) ?[]const u8 {
    // RESP array format: *<count>\r\n$<len>\r\n<cmd>\r\n...
    var iter = std.mem.splitSequence(u8, data, "\r\n");

    const array_line = iter.next() orelse return null;
    if (array_line.len == 0 or array_line[0] != '*') return null;

    // skip command length line ($<len>)
    _ = iter.next() orelse return null;

    const cmd = iter.next() orelse return null;

    if (std.ascii.eqlIgnoreCase(cmd, "ping")) {
        return "+PONG\r\n";
    } else if (std.ascii.eqlIgnoreCase(cmd, "echo")) {
        _ = iter.next() orelse return null; // skip $<len>
        const arg = iter.next() orelse return null;
        return std.fmt.bufPrint(out, "${d}\r\n{s}\r\n", .{ arg.len, arg }) catch return null;
    }

    return "-ERR unknown command\r\n";
}

fn handleConnection(connection: net.Server.Connection) void {
    defer connection.stream.close();

    var buf: [1024]u8 = undefined;
    var resp_buf: [1024]u8 = undefined;
    while (true) {
        const n = connection.stream.read(&buf) catch break;
        if (n == 0) break;
        const response = parseAndRespond(buf[0..n], &resp_buf) orelse "-ERR parse error\r\n";
        connection.stream.writeAll(response) catch break;
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
