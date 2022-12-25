const bitboard = @import("../utils/bitboard.zig");

const console = @import("../utils/console.zig");

const masks = @import("masks.zig");

const Color = @import("../types/enums.zig").Color;
const Square = @import("../types/enums.zig").Square;
const File = @import("../types/enums.zig").File;
const Piece = @import("../types/Piece.zig");

pub const north_bb = northBB();
pub const south_bb = southBB();
pub const east_bb = eastBB();
pub const west_bb = westBB();
pub const north_west_bb = northWestBB();
pub const south_west_bb = southWestBB();
pub const north_east_bb = northEastBB();
pub const south_east_bb = southEastBB();

const pawn_attacks_bb = pawnAttacksBB();
const knight_attacks_bb = knightAttacksBB();
const bishop_pseudo_attacks_bb = bishopPseudoAttacksBB();
const rook_pseudo_attacks_bb = rookPseudoAttacksBB();
const queen_pseudo_attacks_bb = queenPseudoAttacksBB();
const king_attacks_bb = kingAttacksBB();

pub fn pawnAttacks(square: Square, color: Color) u64 {
    return pawn_attacks_bb[@enumToInt(color)][@enumToInt(square)];
}

pub fn nonPawnAttacks(piece_type: Piece.Type, square: Square, occupancy_bb: u64) u64 {
    return switch (piece_type) {
        .Knight => return knightAttacks(square),
        .Bishop => return bishopAttacks(square, occupancy_bb),
        .Rook => return rookAttacks(square, occupancy_bb),
        .Queen => return queenAttacks(square, occupancy_bb),
        .King => return kingAttacks(square),
        else => unreachable,
    };
}

pub fn knightAttacks(square: Square) u64 {
    return knight_attacks_bb[@enumToInt(square)];
}

pub fn bishopAttacks(square: Square, occupancy_bb: u64) u64 {
    const square_v = @enumToInt(square);

    const nw_blockers = (north_west_bb[square_v] & occupancy_bb) | Square.A8.toBitboard();
    const ne_blockers = (north_east_bb[square_v] & occupancy_bb) | Square.H8.toBitboard();
    const sw_blockers = (south_west_bb[square_v] & occupancy_bb) | Square.A1.toBitboard();
    const se_blockers = (south_east_bb[square_v] & occupancy_bb) | Square.H1.toBitboard();

    return bishop_pseudo_attacks_bb[square_v] ^
        north_west_bb[bitboard.bitscanForward(nw_blockers)] ^
        north_east_bb[bitboard.bitscanForward(ne_blockers)] ^
        south_west_bb[bitboard.bitscanReverse(sw_blockers)] ^
        south_east_bb[bitboard.bitscanReverse(se_blockers)];
}

pub fn rookAttacks(square: Square, occupancy_bb: u64) u64 {
    const square_v = @enumToInt(square);

    const n_blockers = (north_bb[square_v] & occupancy_bb) | Square.H8.toBitboard();
    const s_blockers = (south_bb[square_v] & occupancy_bb) | Square.A1.toBitboard();
    const w_blockers = (west_bb[square_v] & occupancy_bb) | Square.A1.toBitboard();
    const e_blockers = (east_bb[square_v] & occupancy_bb) | Square.H8.toBitboard();

    return rook_pseudo_attacks_bb[square_v] ^
        north_bb[bitboard.bitscanForward(n_blockers)] ^
        south_bb[bitboard.bitscanReverse(s_blockers)] ^
        west_bb[bitboard.bitscanReverse(w_blockers)] ^
        east_bb[bitboard.bitscanForward(e_blockers)];
}

pub fn queenAttacks(square: Square, occupancy_bb: u64) u64 {
    return rookAttacks(square, occupancy_bb) | bishopAttacks(square, occupancy_bb);
}

pub fn kingAttacks(square: Square) u64 {
    return king_attacks_bb[@enumToInt(square)];
}

fn northBB() [64]u64 {
    var attacks: [64]u64 = [_]u64{0} ** 64;
    var square = @enumToInt(Square.A1);
    while (square <= @enumToInt(Square.H7)) : (square += 1) {
        var bb: u64 = 0;
        var attack_sq: i32 = square + 8;
        while (attack_sq <= @enumToInt(Square.H8)) : (attack_sq += 8) {
            bb |= bitboard.toBitboard(@intCast(u6, attack_sq));
        }
        attacks[square] = bb;
    }
    return attacks;
}

fn southBB() [64]u64 {
    var attacks: [64]u64 = [_]u64{0} ** 64;
    var square = @enumToInt(Square.A2);
    while (square <= @enumToInt(Square.H8)) : (square += 1) {
        var bb: u64 = 0;
        var attack_sq: i32 = square - 8;
        while (attack_sq >= @enumToInt(Square.A1)) : (attack_sq -= 8) {
            bb |= bitboard.toBitboard(@intCast(u6, attack_sq));
        }
        attacks[square] = bb;
    }
    return attacks;
}

fn eastBB() [64]u64 {
    var attacks: [64]u64 = [_]u64{0} ** 64;
    var square = @enumToInt(Square.A1);
    while (square <= @enumToInt(Square.G8)) : (square += 1) {
        var bb: u64 = 0;
        var attack_sq: i32 = square + 1;
        while (attack_sq <= @enumToInt(Square.H8)) : (attack_sq += 1) {
            const bb_tmp = bitboard.toBitboard(@intCast(u6, attack_sq));
            if ((bb_tmp & masks.file_masks[@enumToInt(File.A)]) != 0) {
                break;
            }
            bb |= bb_tmp;
        }
        attacks[square] = bb;
    }
    return attacks;
}

fn westBB() [64]u64 {
    var attacks: [64]u64 = [_]u64{0} ** 64;
    var square = @enumToInt(Square.B1);
    while (square <= @enumToInt(Square.H8)) : (square += 1) {
        var bb: u64 = 0;
        var attack_sq: i32 = square - 1;
        while (attack_sq >= @enumToInt(Square.A1)) : (attack_sq -= 1) {
            const bb_tmp = bitboard.toBitboard(@intCast(u6, attack_sq));
            if ((bb_tmp & masks.file_masks[@enumToInt(File.H)]) != 0) {
                break;
            }
            bb |= bb_tmp;
        }
        attacks[square] = bb;
    }
    return attacks;
}

fn northWestBB() [64]u64 {
    var attacks: [64]u64 = [_]u64{0} ** 64;
    var square = @enumToInt(Square.A1);
    while (square <= @enumToInt(Square.H7)) : (square += 1) {
        var bb: u64 = 0;
        var attack_sq: i32 = square + 7;
        while (attack_sq <= @enumToInt(Square.H8)) : (attack_sq += 7) {
            const bb_tmp = bitboard.toBitboard(@intCast(u6, attack_sq));
            if ((bb_tmp & masks.file_masks[@enumToInt(File.H)]) != 0) {
                break;
            }
            bb |= bb_tmp;
        }
        attacks[square] = bb;
    }
    return attacks;
}

fn southWestBB() [64]u64 {
    var attacks: [64]u64 = [_]u64{0} ** 64;
    var square = @enumToInt(Square.B2);
    while (square <= @enumToInt(Square.H8)) : (square += 1) {
        var bb: u64 = 0;
        var attack_sq: i32 = square - 9;
        while (attack_sq >= @enumToInt(Square.A1)) : (attack_sq -= 9) {
            const bb_tmp = bitboard.toBitboard(@intCast(u6, attack_sq));
            if ((bb_tmp & masks.file_masks[@enumToInt(File.H)]) != 0) {
                break;
            }
            bb |= bb_tmp;
        }
        attacks[square] = bb;
    }
    return attacks;
}

fn northEastBB() [64]u64 {
    var attacks: [64]u64 = [_]u64{0} ** 64;
    var square = @enumToInt(Square.A1);
    while (square <= @enumToInt(Square.G7)) : (square += 1) {
        var bb: u64 = 0;
        var attack_sq: i32 = square + 9;
        while (attack_sq <= @enumToInt(Square.H8)) : (attack_sq += 9) {
            const bb_tmp = bitboard.toBitboard(@intCast(u6, attack_sq));
            if ((bb_tmp & masks.file_masks[@enumToInt(File.A)]) != 0) {
                break;
            }
            bb |= bb_tmp;
        }
        attacks[square] = bb;
    }
    return attacks;
}

fn southEastBB() [64]u64 {
    var attacks: [64]u64 = [_]u64{0} ** 64;
    var square = @enumToInt(Square.A2);
    while (square <= @enumToInt(Square.H8)) : (square += 1) {
        var bb: u64 = 0;
        var attack_sq: i32 = square - 7;
        while (attack_sq >= @enumToInt(Square.A1)) : (attack_sq -= 7) {
            const bb_tmp = bitboard.toBitboard(@intCast(u6, attack_sq));
            if ((bb_tmp & masks.file_masks[@enumToInt(File.A)]) != 0) {
                break;
            }
            bb |= bb_tmp;
        }
        attacks[square] = bb;
    }
    return attacks;
}

fn pawnAttacksBB() [2][64]u64 {
    var attacks: [2][64]u64 = [2][64]u64{
        [_]u64{0} ** 64,
        [_]u64{0} ** 64,
    };
    for (Square.all) |square| {
        const square_v = @enumToInt(square);
        if (square_v <= @enumToInt(Square.H7)) {
            attacks[@enumToInt(Color.White)][square_v] |= bitboard.toBitboard(@intCast(u6, square_v + 7)) & ~masks.file_masks[@enumToInt(File.H)];
        }
        if (square_v <= @enumToInt(Square.G7)) {
            attacks[@enumToInt(Color.White)][square_v] |= bitboard.toBitboard(@intCast(u6, square_v + 9)) & ~masks.file_masks[@enumToInt(File.A)];
        }
        if (square_v >= @enumToInt(Square.A2)) {
            attacks[@enumToInt(Color.Black)][square_v] |= bitboard.toBitboard(@intCast(u6, square_v - 7)) & ~masks.file_masks[@enumToInt(File.A)];
        }
        if (square_v >= @enumToInt(Square.B2)) {
            attacks[@enumToInt(Color.Black)][square_v] |= bitboard.toBitboard(@intCast(u6, square_v - 9)) & ~masks.file_masks[@enumToInt(File.H)];
        }
    }
    return attacks;
}

fn knightAttacksBB() [64]u64 {
    var attacks: [64]u64 = [_]u64{0} ** 64;
    for (Square.all) |square| {
        const square_v = @enumToInt(square);
        if (square_v <= @enumToInt(Square.G6)) {
            attacks[square_v] |= bitboard.toBitboard(@intCast(u6, square_v + 17)) & ~masks.file_masks[@enumToInt(File.A)];
        }
        if (square_v <= @enumToInt(Square.H6)) {
            attacks[square_v] |= bitboard.toBitboard(@intCast(u6, square_v + 15)) & ~masks.file_masks[@enumToInt(File.H)];
        }
        if (square_v >= @enumToInt(Square.B3)) {
            attacks[square_v] |= bitboard.toBitboard(@intCast(u6, square_v - 17)) & ~masks.file_masks[@enumToInt(File.H)];
        }
        if (square_v >= @enumToInt(Square.A3)) {
            attacks[square_v] |= bitboard.toBitboard(@intCast(u6, square_v - 15)) & ~masks.file_masks[@enumToInt(File.A)];
        }
        if (square_v <= @enumToInt(Square.F7)) {
            attacks[square_v] |= bitboard.toBitboard(@intCast(u6, square_v + 10)) & ~(masks.file_masks[@enumToInt(File.A)] | masks.file_masks[@enumToInt(File.B)]);
        }
        if (square_v <= @enumToInt(Square.H7)) {
            attacks[square_v] |= bitboard.toBitboard(@intCast(u6, square_v + 6)) & ~(masks.file_masks[@enumToInt(File.H)] | masks.file_masks[@enumToInt(File.G)]);
        }
        if (square_v >= @enumToInt(Square.C2)) {
            attacks[square_v] |= bitboard.toBitboard(@intCast(u6, square_v - 10)) & ~(masks.file_masks[@enumToInt(File.H)] | masks.file_masks[@enumToInt(File.G)]);
        }
        if (square_v >= @enumToInt(Square.A2)) {
            attacks[square_v] |= bitboard.toBitboard(@intCast(u6, square_v - 6)) & ~(masks.file_masks[@enumToInt(File.A)] | masks.file_masks[@enumToInt(File.B)]);
        }
    }
    return attacks;
}

fn kingAttacksBB() [64]u64 {
    var attacks: [64]u64 = [_]u64{0} ** 64;
    for (Square.all) |square| {
        const square_v = @enumToInt(square);
        if (square_v <= @enumToInt(Square.G7)) {
            attacks[square_v] |= bitboard.toBitboard(@intCast(u6, square_v + 9)) & ~masks.file_masks[@enumToInt(File.A)];
        }
        if (square_v <= @enumToInt(Square.H7)) {
            attacks[square_v] |= @intCast(u64, 1) << @intCast(u6, square_v + 8);
            attacks[square_v] |= bitboard.toBitboard(@intCast(u6, square_v + 7)) & ~masks.file_masks[@enumToInt(File.H)];
        }
        if (square_v <= @enumToInt(Square.G8)) {
            attacks[square_v] |= bitboard.toBitboard(@intCast(u6, square_v + 1)) & ~masks.file_masks[@enumToInt(File.A)];
        }
        if (square_v >= @enumToInt(Square.B1)) {
            attacks[square_v] |= bitboard.toBitboard(@intCast(u6, square_v - 1)) & ~masks.file_masks[@enumToInt(File.H)];
        }
        if (square_v >= @enumToInt(Square.A2)) {
            attacks[square_v] |= bitboard.toBitboard(@intCast(u6, square_v - 7)) & ~masks.file_masks[@enumToInt(File.A)];
            attacks[square_v] |= @intCast(u64, 1) << @intCast(u6, square_v - 8);
        }
        if (square_v >= @enumToInt(Square.B2)) {
            attacks[square_v] |= bitboard.toBitboard(@intCast(u6, square_v - 9)) & ~masks.file_masks[@enumToInt(File.H)];
        }
    }
    return attacks;
}

fn bishopPseudoAttacksBB() [64]u64 {
    var attacks: [64]u64 = [_]u64{0} ** 64;
    for (Square.all) |square| {
        const square_v = @enumToInt(square);
        attacks[square_v] =
            north_east_bb[square_v] |
            north_west_bb[square_v] |
            south_east_bb[square_v] |
            south_west_bb[square_v];
    }
    return attacks;
}

fn rookPseudoAttacksBB() [64]u64 {
    var attacks: [64]u64 = [_]u64{0} ** 64;
    for (Square.all) |square| {
        const square_v = @enumToInt(square);
        attacks[square_v] =
            north_bb[square_v] |
            south_bb[square_v] |
            east_bb[square_v] |
            west_bb[square_v];
    }
    return attacks;
}

fn queenPseudoAttacksBB() [64]u64 {
    var attacks: [64]u64 = [_]u64{0} ** 64;
    for (Square.all) |square| {
        const square_v = @enumToInt(square);
        attacks[square_v] =
            north_bb[square_v] |
            south_bb[square_v] |
            east_bb[square_v] |
            west_bb[square_v] |
            north_east_bb[square_v] |
            north_west_bb[square_v] |
            south_east_bb[square_v] |
            south_west_bb[square_v];
    }
    return attacks;
}
