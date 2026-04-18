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

pub const Waiter = struct {
    cond: std.Thread.Condition = .{},
    resolved_key: []const u8 = undefined,
    result: ?[]const u8 = null,
};

pub const List = struct {
    map: std.StringHashMap(std.ArrayList([]const u8)),
    waiters: std.StringHashMap(std.ArrayList(*Waiter)),
    mutex: std.Thread.Mutex,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) List {
        return .{
            .map = std.StringHashMap(std.ArrayList([]const u8)).init(allocator),
            .waiters = std.StringHashMap(std.ArrayList(*Waiter)).init(allocator),
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
        var wit = self.waiters.iterator();
        while (wit.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
        }
        self.waiters.deinit();
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
        const len = result.value_ptr.items.len;
        self.resolveWaiters(key);
        return len;
    }

    pub fn lpush(self: *List, key: []const u8, vals: []const []const u8) !usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        const result = try self.map.getOrPut(key);
        if (!result.found_existing) {
            const key_copy = try self.allocator.dupe(u8, key);
            result.key_ptr.* = key_copy;
            result.value_ptr.* = std.ArrayList([]const u8){};
        }
        // insert each val at front left-to-right: LPUSH key a b → [b, a, ...]
        for (vals) |val| {
            const val_copy = try self.allocator.dupe(u8, val);
            try result.value_ptr.insert(self.allocator, 0, val_copy);
        }

        const len = result.value_ptr.items.len;
        self.resolveWaiters(key);
        return len;
    }

    pub fn lrange(self: *List, key: []const u8, start: i64, end: i64) ?[]const []const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();
        const items = if (self.map.get(key)) |l| l.items else return null;
        const len = @as(i64, @intCast(items.len));
        const s = if (start < 0) @max(len + start, 0) else @min(start, len);
        const e = if (end < 0) len + end + 1 else @min(end + 1, len);
        if (s >= e) return &[_][]const u8{};
        return items[@intCast(s)..@intCast(e)];
    }

    pub fn llen(self: *List, key: []const u8) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        const items = if (self.map.get(key)) |l| l.items else return 0;
        return items.len;
    }

    pub fn lpop(self: *List, key: []const u8) ?[]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        const list_ptr = self.map.getPtr(key) orelse return null;
        if (list_ptr.items.len == 0) return null;
        return list_ptr.orderedRemove(0);
    }

    // Called while self.mutex is held. Wakes the first waiter for `key` if
    // the list has an element available.
    fn resolveWaiters(self: *List, key: []const u8) void {
        const entry = self.waiters.getEntry(key) orelse return;
        const stored_key = entry.key_ptr.*;
        const waiter_list = entry.value_ptr;
        while (waiter_list.items.len > 0) {
            const list_ptr = self.map.getPtr(key) orelse return;
            if (list_ptr.items.len == 0) return;
            const w = waiter_list.orderedRemove(0);
            const val = list_ptr.orderedRemove(0);
            w.result = val;
            w.resolved_key = stored_key;
            w.cond.signal();
        }
    }

    pub fn blpop(self: *List, keys: []const []const u8, timeout_ms: u64) ?[2][]const u8 {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Fast path: check if any key already has elements.
        for (keys) |key| {
            const list_ptr = self.map.getPtr(key) orelse continue;
            if (list_ptr.items.len > 0) {
                const val = list_ptr.orderedRemove(0);
                return .{ key, val };
            }
        }

        // Register waiter on all requested keys.
        var waiter = Waiter{};
        for (keys) |key| {
            const res = self.waiters.getOrPut(key) catch continue;
            if (!res.found_existing) {
                const key_copy = self.allocator.dupe(u8, key) catch continue;
                res.key_ptr.* = key_copy;
                res.value_ptr.* = std.ArrayList(*Waiter){};
            }
            res.value_ptr.append(self.allocator, &waiter) catch {};
        }

        // Block until an element arrives or timeout expires.
        if (timeout_ms == 0) {
            while (waiter.result == null) {
                waiter.cond.wait(&self.mutex);
            }
        } else {
            const deadline = std.time.nanoTimestamp() +
                @as(i128, @intCast(timeout_ms)) * std.time.ns_per_ms;
            while (waiter.result == null) {
                const now = std.time.nanoTimestamp();
                if (now >= deadline) break;
                const remaining: u64 = @intCast(deadline - now);
                waiter.cond.timedWait(&self.mutex, remaining) catch break;
            }
        }

        // Remove waiter from all keys (handles both resolved and timed-out cases).
        for (keys) |key| {
            const wl = self.waiters.getPtr(key) orelse continue;
            for (wl.items, 0..) |w, i| {
                if (w == &waiter) {
                    _ = wl.orderedRemove(i);
                    break;
                }
            }
        }

        if (waiter.result) |val| return .{ waiter.resolved_key, val };
        return null;
    }

    /// Pops up to `buf.len` elements from the front of the list into `buf`.
    /// Returns the number of elements actually popped.
    pub fn lpopN(self: *List, key: []const u8, buf: [][]const u8) usize {
        self.mutex.lock();
        defer self.mutex.unlock();

        const list_ptr = self.map.getPtr(key) orelse return 0;
        const n = @min(buf.len, list_ptr.items.len);
        for (0..n) |i| {
            buf[i] = list_ptr.orderedRemove(0);
        }
        return n;
    }
};
