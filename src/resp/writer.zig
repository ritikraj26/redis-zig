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

pub const emptyArray = "*0\r\n";

pub fn integer(out: []u8, n: usize) ?[]const u8 {
    return std.fmt.bufPrint(out, ":{d}\r\n", .{n}) catch return null;
}

pub fn array(out: []u8, items: []const []const u8) ?[]const u8 {
    var written: usize = 0;
    written += (std.fmt.bufPrint(out[written..], "*{d}\r\n", .{items.len}) catch return null).len;
    for (items) |item| {
        written += (std.fmt.bufPrint(out[written..], "${d}\r\n{s}\r\n", .{ item.len, item }) catch return null).len;
    }
    return out[0..written];
}
