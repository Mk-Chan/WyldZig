const std = @import("std");

const stdout = std.io.getStdOut().writer();
const stdin = std.io.getStdIn().reader();

pub fn printf(comptime fmt: []const u8, args: anytype) void {
    stdout.print(fmt, args) catch |err| {};
}

pub fn println(comptime fmt: []const u8, args: anytype) void {
    printf(fmt ++ "\n", args);
}

pub fn printNewLine() void {
    printf("\n", .{});
}

pub fn readln(buf: []u8) ?[]u8 {
    return stdin.readUntilDelimiterOrEof(buf, '\n') catch |err| {
        return null;
    };
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
