const std = @import("std");
const Store = @import("store/store.zig").Store;
const server = @import("server/server.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    var store = Store.init(gpa.allocator());
    defer store.deinit();
    try server.run(&store);
}
