const std = @import("std");

pub fn equals(s1: []const u8, s2: []const u8) bool {
    return std.mem.eql(u8, s1, s2);
}

pub fn startsWith(text: []const u8, prefix: []const u8) bool {
    return std.mem.startsWith(u8, text, prefix);
}
