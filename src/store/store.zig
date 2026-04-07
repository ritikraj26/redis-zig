const std = @import("std");

pub const Store = struct {
    map: std.StringHashMap([]const u8),
    mutex: std.Thread.Mutex,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Store {
        return .{
            .map = std.StringHashMap([]const u8).init(allocator),
            .mutex = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Store) void {
        self.map.deinit();
    }

    pub fn get(self: *Store, key: []const u8) ?[]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.map.get(key);
    }

    pub fn set(self: *Store, key: []const u8, val: []const u8) !void {
        const key_copy = try self.allocator.dupe(u8, key);
        const val_copy = try self.allocator.dupe(u8, val);
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.map.put(key_copy, val_copy);
    }
};
