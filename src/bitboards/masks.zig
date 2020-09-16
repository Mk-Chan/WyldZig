const Square = @import("../types/enums.zig").Square;

const attacks = @import("attacks.zig");

pub const file_masks = [8]u64{ 0x0101010101010101, 0x0202020202020202, 0x0404040404040404, 0x0808080808080808, 0x1010101010101010, 0x2020202020202020, 0x4040404040404040, 0x8080808080808080 };
pub const rank_masks = [8]u64{ 0xff, 0xff00, 0xff0000, 0xff000000, 0xff00000000, 0xff0000000000, 0xff000000000000, 0xff00000000000000 };

pub const xray_masks: [64][64]u64 = comptime xrayMaskBB();
pub const intervening_masks: [64][64]u64 = comptime interveningMaskBB();

fn xrayMaskBB() [64][64]u64 {
    _ = @setEvalBranchQuota(33000);
    var masks: [64][64]u64 = undefined;
    var from: i32 = 0;
    while (from < 64) : (from += 1) {
        var to: i32 = 0;
        while (to < 64) : (to += 1) {
            masks[@intCast(usize, from)][@intCast(usize, to)] = 0;
        }
    }

    from = 0;
    while (from < 64) : (from += 1) {
        var to: i32 = 0;
        while (to < 64) : (to += 1) {
            if (from == to) {
                continue;
            }

            var high = to;
            var low = from;
            if (low > high) {
                high = from;
                low = to;
            }
            if ((high & 7) == (low & 7)) {
                masks[@intCast(usize, from)][@intCast(usize, to)] |= attacks.rookAttacks(@intToEnum(Square, @intCast(u8, high)), 0) & attacks.rookAttacks(@intToEnum(Square, @intCast(u8, low)), 0);
            }
            if ((high >> 3) == (low >> 3)) {
                masks[@intCast(usize, from)][@intCast(usize, to)] |= attacks.rookAttacks(@intToEnum(Square, @intCast(u8, high)), 0) & attacks.rookAttacks(@intToEnum(Square, @intCast(u8, low)), 0);
            }
            if ((high >> 3) - (low >> 3) == (high & 7) - (low & 7)) {
                masks[@intCast(usize, from)][@intCast(usize, to)] |= attacks.bishopAttacks(@intToEnum(Square, @intCast(u8, high)), 0) & attacks.bishopAttacks(@intToEnum(Square, @intCast(u8, low)), 0);
            }
            if ((high >> 3) - (low >> 3) == (low & 7) - (high & 7)) {
                masks[@intCast(usize, from)][@intCast(usize, to)] |= attacks.bishopAttacks(@intToEnum(Square, @intCast(u8, high)), 0) & attacks.bishopAttacks(@intToEnum(Square, @intCast(u8, low)), 0);
            }
        }
    }
    return masks;
}

fn interveningMaskBB() [64][64]u64 {
    _ = @setEvalBranchQuota(33000);
    var masks: [64][64]u64 = undefined;
    var from: i32 = 0;
    while (from < 64) : (from += 1) {
        var to: i32 = 0;
        while (to < 64) : (to += 1) {
            masks[@intCast(usize, from)][@intCast(usize, to)] = 0;
        }
    }

    from = 0;
    while (from < 64) : (from += 1) {
        var to: i32 = 0;
        while (to < 64) : (to += 1) {
            if (from == to) {
                continue;
            }

            var high = to;
            var low = from;
            if (low > high) {
                high = from;
                low = to;
            }
            if ((high & 7) == (low & 7)) {
                high -= 8;
                while (high > low) {
                    masks[@intCast(usize, from)][@intCast(usize, to)] |= @intToEnum(Square, @intCast(u8, high)).toBitboard();
                    high -= 8;
                }
            }
            if ((high >> 3) == (low >> 3)) {
                high -= 1;
                while (high > low) {
                    masks[@intCast(usize, from)][@intCast(usize, to)] |= @intToEnum(Square, @intCast(u8, high)).toBitboard();
                    high -= 1;
                }
            }
            if ((high >> 3) - (low >> 3) == (high & 7) - (low & 7)) {
                high -= 9;
                while (high > low) {
                    masks[@intCast(usize, from)][@intCast(usize, to)] |= @intToEnum(Square, @intCast(u8, high)).toBitboard();
                    high -= 9;
                }
            }
            if ((high >> 3) - (low >> 3) == (low & 7) - (high & 7)) {
                high -= 7;
                while (high > low) {
                    masks[@intCast(usize, from)][@intCast(usize, to)] |= @intToEnum(Square, @intCast(u8, high)).toBitboard();
                    high -= 7;
                }
            }
        }
    }
    return masks;
}
