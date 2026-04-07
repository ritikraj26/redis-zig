const std = @import("std");

pub const ok = "+OK\r\n";
pub const pong = "+PONG\r\n";
pub const nil = "$-1\r\n";
pub const err_unknown = "-ERR unknown command\r\n";
pub const err_args = "-ERR wrong number of arguments\r\n";
pub const err_parse = "-ERR parse error\r\n";

pub fn bulkString(out: []u8, s: []const u8) ?[]const u8 {
    return std.fmt.bufPrint(out, "${d}\r\n{s}\r\n", .{ s.len, s }) catch return null;
}
