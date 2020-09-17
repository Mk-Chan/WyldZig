const std = @import("std");

const Square = @import("../types/enums.zig").Square;

pub inline fn toBitboard(shift_value: u6) u64 {
    return @as(u64, 1) << shift_value;
}

pub inline fn bitscanForward(bb: u64) u7 {
    return @ctz(u64, bb);
}

pub inline fn bitscanReverse(bb: u64) u7 {
    return 63 - @clz(u64, bb);
}

pub inline fn popcount(bb: u64) u7 {
    return @popCount(u64, bb);
}

pub inline fn popBitForward(bb: *u64) void {
    bb.* &= bb.* - 1;
}

pub inline fn popBitReverse(bb: *u64) void {
    bb.* ^= @as(u64, 1) << @as(u6, bitscanReverse(bb.*) + 1);
}
