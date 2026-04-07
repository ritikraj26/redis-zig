const std = @import("std");

pub const Entry = struct {
    value: []const u8,
    expires_at_ms: ?i64, // absolute unix time in milliseconds, null = no expiry

    pub fn isExpired(self: Entry) bool {
        const exp = self.expires_at_ms orelse return false;
        return std.time.milliTimestamp() >= exp;
    }
};

pub const Store = struct {
    map: std.StringHashMap(Entry),
    mutex: std.Thread.Mutex,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Store {
        return .{
            .map = std.StringHashMap(Entry).init(allocator),
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
        const entry = self.map.get(key) orelse return null;
        if (entry.isExpired()) return null;
        return entry.value;
    }

    pub fn set(self: *Store, key: []const u8, val: []const u8) !void {
        try self.setWithTTL(key, val, null);
    }

    pub fn setWithTTL(self: *Store, key: []const u8, val: []const u8, ttl_ms: ?u64) !void {
        const key_copy = try self.allocator.dupe(u8, key);
        const val_copy = try self.allocator.dupe(u8, val);
        const expires_at_ms: ?i64 = if (ttl_ms) |ms|
            std.time.milliTimestamp() + @as(i64, @intCast(ms))
        else
            null;
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.map.put(key_copy, Entry{ .value = val_copy, .expires_at_ms = expires_at_ms });
    }
};
