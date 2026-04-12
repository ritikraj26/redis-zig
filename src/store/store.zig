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

pub const List = struct {
    map: std.StringHashMap(std.ArrayList([]const u8)),
    mutex: std.Thread.Mutex,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) List {
        return .{
            .map = std.StringHashMap(std.ArrayList([]const u8)).init(allocator),
            .mutex = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *List) void {
        var it = self.map.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.map.deinit();
    }

    // use []const []const u8 when the storage does't need to grw, read only
    // use std.ArrayList when the storage needs to grow
    pub fn rpush(self: *List, key: []const u8, vals: []const []const u8) !usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        const result = try self.map.getOrPut(key);
        if (!result.found_existing) {
            const key_copy = try self.allocator.dupe(u8, key);
            result.key_ptr.* = key_copy;
            result.value_ptr.* = std.ArrayList([]const u8){};
        }
        for (vals) |val| {
            const val_copy = try self.allocator.dupe(u8, val);
            try result.value_ptr.append(self.allocator, val_copy);
        }
        // try result.value_ptr.append(self.allocator, val_copy);
        return result.value_ptr.items.len;
    }
};
