const std = @import("std");

pub const MAX_ARGS = 16;

pub const Command = struct {
    name: []const u8,
    args: [MAX_ARGS][]const u8,
    args_len: usize,
};

pub fn parse(data: []const u8) ?Command {
    var iter = std.mem.splitSequence(u8, data, "\r\n");

    const array_line = iter.next() orelse return null;
    if (array_line.len == 0 or array_line[0] != '*') return null;

    const count = std.fmt.parseInt(usize, array_line[1..], 10) catch return null;
    if (count == 0) return null;

    _ = iter.next() orelse return null; // skip $<len>
    const name = iter.next() orelse return null;

    var cmd = Command{ .name = name, .args = undefined, .args_len = 0 };

    var i: usize = 0;
    while (i < count - 1 and i < MAX_ARGS) : (i += 1) {
        _ = iter.next() orelse return null; // skip $<len>
        cmd.args[i] = iter.next() orelse return null;
        cmd.args_len += 1;
    }

    return cmd;
}
