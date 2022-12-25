const std = @import("std");

pub fn printf(comptime fmt: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    stdout.print(fmt, args) catch {};
}

pub fn println(comptime fmt: []const u8, args: anytype) void {
    printf(fmt ++ "\n", args);
}

pub fn printNewLine() void {
    printf("\n", .{});
}

pub fn readln(buf: []u8) []const u8 {
    const stdin = std.io.getStdIn().reader();
    var line = stdin.readUntilDelimiterOrEof(buf, '\n') catch {
        unreachable;
    } orelse unreachable;
    return std.mem.trimRight(u8, line[0..], "\r");
}

pub fn printBitboard(bitboard: u64) void {
    var sq: usize = 0;
    while (sq < 64) {
        if (sq != 0 and (sq & 7) == 0) {
            println("", .{});
        }
        if (((@as(u64, 1) << @as(u6, (sq ^ 56))) & bitboard) != 0) {
            printf("X ", .{});
        } else {
            printf("- ", .{});
        }
        sq += 1;
    }
    println("", .{});
}
