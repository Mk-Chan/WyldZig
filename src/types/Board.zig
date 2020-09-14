const Board = @This();

const std = @import("std");
const assert = std.debug.assert;

const attacks = @import("../bitboards/attacks.zig");
const bitboard = @import("../utils/bitboard.zig");
const console = @import("../utils/console.zig");
const masks = @import("../bitboards/masks.zig");

const Color = @import("enums.zig").Color;
const Rank = @import("enums.zig").Rank;
const File = @import("enums.zig").File;
const Square = @import("enums.zig").Square;
const Piece = @import("Piece.zig");
const Move = @import("Move.zig");
const MoveList = @import("MoveList.zig");

// Data members start
piece_bitboards: [6]u64 = undefined,
color_bitboards: [2]u64 = undefined,
enpassant_square: Square = undefined,
castling_rights_bitset: u4 = undefined,
side_to_move: Color = undefined,
// Data members end

// zig fmt: off
const castling_spoilers = [_]u4{
    13, 15, 15, 15, 12, 15, 15, 14,
    15, 15, 15, 15, 15, 15, 15, 15,
    15, 15, 15, 15, 15, 15, 15, 15,
    15, 15, 15, 15, 15, 15, 15, 15,
    15, 15, 15, 15, 15, 15, 15, 15,
    15, 15, 15, 15, 15, 15, 15, 15,
    15, 15, 15, 15, 15, 15, 15, 15,
     7, 15, 15, 15,  3, 15, 15, 11
};
// zig fmt: on

pub fn makeMove(self: *Board, move: Move) void {
    const from = move.from_square;
    const to = move.to_square;
    const move_type = self.moveTypeOf(move);
    const side_to_move = self.side_to_move;
    const opposite_side = side_to_move.reverse();

    self.side_to_move = opposite_side;
    self.enpassant_square = .None;
    self.castling_rights_bitset &= castling_spoilers[@enumToInt(from)] & castling_spoilers[@enumToInt(to)];

    switch (move_type) {
        .Normal => self.movePiece(Piece{ .type = self.pieceTypeOn(from), .color = side_to_move }, from, to),
        .Capture => {
            self.removePiece(Piece{ .type = self.pieceTypeOn(to), .color = opposite_side }, to);
            self.movePiece(Piece{ .type = self.pieceTypeOn(from), .color = side_to_move }, from, to);
        },
        .DoublePush => {
            self.movePiece(Piece{ .type = .Pawn, .color = side_to_move }, from, to);
            self.enpassant_square = if (side_to_move == .White) @intToEnum(Square, @enumToInt(from) + 8) else @intToEnum(Square, (@enumToInt(from) - 8));
        },
        .Enpassant => {
            const captured_piece_square = if (side_to_move == Color.White) @intToEnum(Square, @enumToInt(to) - 8) else @intToEnum(Square, (@enumToInt(to) + 8));
            self.movePiece(Piece{ .type = .Pawn, .color = side_to_move }, from, to);
            self.removePiece(Piece{ .type = .Pawn, .color = opposite_side }, captured_piece_square);
        },
        .Castling => {
            self.movePiece(Piece{ .type = .King, .color = side_to_move }, from, to);
            switch (to) {
                .C1 => self.movePiece(Piece{ .type = .Rook, .color = side_to_move }, .A1, .D1),
                .G1 => self.movePiece(Piece{ .type = .Rook, .color = side_to_move }, .H1, .F1),
                .C8 => self.movePiece(Piece{ .type = .Rook, .color = side_to_move }, .A8, .D8),
                .G8 => self.movePiece(Piece{ .type = .Rook, .color = side_to_move }, .H8, .F8),
                else => unreachable,
            }
        },
        .CapturePromotion => {
            self.removePiece(Piece{ .type = self.pieceTypeOn(to), .color = opposite_side }, to);
            self.removePiece(Piece{ .type = .Pawn, .color = side_to_move }, from);
            self.putPiece(Piece{ .type = move.promotion_piece_type, .color = side_to_move }, to);
        },
        .Promotion => {
            self.removePiece(Piece{ .type = .Pawn, .color = side_to_move }, from);
            self.putPiece(Piece{ .type = move.promotion_piece_type, .color = side_to_move }, to);
        },
        .None => unreachable,
    }
}

pub fn pieceTypeOn(self: *Board, square: Square) Piece.Type {
    const square_bb = square.toBitboard();
    for (Piece.Type.all) |piece_type| {
        if ((self.piece_bitboards[@enumToInt(piece_type)] & square_bb) != 0) {
            return piece_type;
        }
    }
    return .None;
}

pub fn pieceOn(self: *Board, square: Square) ?Piece {
    const square_bb = square.toBitboard();
    var pt = Piece.Type.None;
    for (Piece.Type.all) |piece_type| {
        if ((self.piece_bitboards[@enumToInt(piece_type)] & square_bb) != 0) {
            pt = piece_type;
            break;
        }
    }
    if (pt == Piece.Type.None) {
        return null;
    }

    const color = if ((self.color_bitboards[@enumToInt(Color.White)] & square_bb) != 0) Color.White else Color.Black;
    return Piece{ .type = pt, .color = color };
}

pub fn parse(fen: []const u8) Board {
    var board = Board{};
    board.clear();

    var fenIndex: u8 = 0;
    var fenSquareIndex: u8 = @enumToInt(Square.A8);
    while (fenIndex < 64) {
        if (fenIndex >= fen.len) {
            unreachable; // TODO: Handle error
        }

        const ch = fen[fenIndex];
        fenIndex += 1;

        if (ch == ' ') {
            break;
        } else if (ch > '0' and ch < '9') {
            fenSquareIndex += (ch - '0');
        } else if (ch == '/') {
            fenSquareIndex -= 16;
        } else {
            const piece = Piece.parse(ch);
            const square = @intToEnum(Square, fenSquareIndex);

            assert(square != .None);

            board.putPiece(piece, square);
            fenSquareIndex += 1;
        }
    }

    var ch = fen[fenIndex];
    board.side_to_move = Color.parse(ch);

    fenIndex += 2;
    ch = fen[fenIndex];
    while (ch != ' ') {
        if (ch == '-') {
            fenIndex += 1;
            break;
        } else {
            board.castling_rights_bitset |= switch (ch) {
                'K' => @intCast(u4, 1),
                'Q' => @intCast(u4, 2),
                'k' => @intCast(u4, 4),
                'q' => @intCast(u4, 8),
                else => unreachable, // TODO: Handle error
            };
        }

        fenIndex += 1;
        ch = fen[fenIndex];
    }

    fenIndex += 1;
    ch = fen[fenIndex];
    if (ch != '-') {
        fenIndex += 1;
        board.enpassant_square = @intToEnum(Square, (ch - 'a') + ((fen[fenIndex] - '1') << 3));
    }

    return board;
}

pub fn print(self: *Board) void {
    for (Square.all) |square| {
        if (square != Square.A1 and (@enumToInt(square) & 7) == 0) {
            console.println("", .{});
        }
        const square_flipped = @intToEnum(Square, @enumToInt(square) ^ 56);
        const optional_piece = self.pieceOn(square_flipped);
        if (optional_piece) |piece| {
            console.printf("{} ", .{&[1]u8{piece.toChar()}});
        } else {
            console.printf("- ", .{});
        }
    }
    console.println("", .{});
}

pub fn clear(self: *Board) void {
    for (Piece.Type.all) |piece_type| {
        self.piece_bitboards[@enumToInt(piece_type)] = 0;
    }
    for (Color.all) |color| {
        self.color_bitboards[@enumToInt(color)] = 0;
    }
    self.enpassant_square = .None;
    self.castling_rights_bitset = 0;
    self.side_to_move = .White;
}

pub fn occupancyBB(self: *Board) u64 {
    return self.color_bitboards[@enumToInt(Color.White)] | self.color_bitboards[@enumToInt(Color.Black)];
}

pub fn sideIsInCheck(self: *Board, color: Color) bool {
    return self.checkersBBToColor(color) != 0;
}

pub fn checkersBBToColor(self: *Board, color: Color) u64 {
    const king_bb = self.piece_bitboards[@enumToInt(Piece.Type.King)];
    const color_bb = self.color_bitboards[@enumToInt(color)];
    const king_square = @intToEnum(Square, bitboard.bitscanForward(king_bb & color_bb));
    return self.attackersBBToSquareByColor(king_square, color.reverse());
}

pub fn attackersBBToSquareByColor(self: *Board, square: Square, color: Color) u64 {
    return self.attackersBBToSquare(square, self.occupancyBB()) & self.color_bitboards[@enumToInt(color)];
}

pub fn attackersBBToSquare(self: *Board, square: Square, occupancy_bb: u64) u64 {
    const pawn_bb = self.piece_bitboards[@enumToInt(Piece.Type.Pawn)];
    var attackers_bb = (attacks.pawnAttacks(square, Color.White) & pawn_bb & self.color_bitboards[@enumToInt(Color.Black)]) |
        (attacks.pawnAttacks(square, Color.Black) & pawn_bb & self.color_bitboards[@enumToInt(Color.White)]);
    for ([_]Piece.Type{ .Knight, .Bishop, .Rook, .Queen, .King }) |piece_type| {
        attackers_bb |= attacks.nonPawnAttacks(piece_type, square, occupancy_bb) & self.piece_bitboards[@enumToInt(piece_type)];
    }
    return attackers_bb;
}

pub fn pinnedBBToColor(self: *Board, color: Color) u64 {
    const king_bb = self.piece_bitboards[@enumToInt(Piece.Type.King)];
    const color_bb = self.color_bitboards[@enumToInt(color)];
    const other_color_bb = self.color_bitboards[@enumToInt(color.reverse())];
    const king_square = @intToEnum(Square, bitboard.bitscanForward(king_bb & color_bb));
    const occupancy_bb = self.occupancyBB();
    var pinners_bb = ((self.piece_bitboards[@enumToInt(Piece.Type.Queen)] | self.piece_bitboards[@enumToInt(Piece.Type.Rook)]) & other_color_bb & attacks.rookAttacks(king_square, 0)) |
        ((self.piece_bitboards[@enumToInt(Piece.Type.Queen)] | self.piece_bitboards[@enumToInt(Piece.Type.Bishop)]) & other_color_bb & attacks.bishopAttacks(king_square, 0));
    var pinned_bb: u64 = 0;
    while (pinners_bb != 0) {
        const square = bitboard.bitscanForward(pinners_bb);
        bitboard.popBitForward(&pinners_bb);
        var bb = masks.intervening_masks[square][@enumToInt(king_square)] & occupancy_bb;
        if (bitboard.popcount(bb) == 1) {
            pinned_bb ^= bb & color_bb;
        }
    }
    return pinned_bb;
}

pub fn generateLegalMoves(self: *Board, move_list_iterator: *MoveList.Iterator) usize {
    const move_list_start = move_list_iterator.iter;
    const start = @ptrToInt(move_list_start);

    if (self.sideIsInCheck(self.side_to_move)) {
        self.generateCheckEvasions(move_list_iterator);
    } else {
        self.generatePseudolegalMoves(move_list_iterator);
    }
    var end = @ptrToInt(move_list_iterator.iter);
    var size: usize = (end - start) / @sizeOf(Move);

    const king_bb = self.piece_bitboards[@enumToInt(Piece.Type.King)];
    const color_bb = self.color_bitboards[@enumToInt(self.side_to_move)];
    const king_square = @intToEnum(Square, bitboard.bitscanForward(king_bb & color_bb));

    const pinned_bb = self.pinnedBBToColor(self.side_to_move);
    var move_index: usize = 0;
    while (move_index < size) {
        const move = move_list_start[move_index];
        if (((pinned_bb & move.from_square.toBitboard()) != 0 or
            move.from_square == king_square or
            (move.to_square == self.enpassant_square and self.pieceTypeOn(move.from_square) == .Pawn)) and
            !self.isLegalGeneratedMove(move, pinned_bb))
        {
            move_list_start[move_index] = move_list_start[size - 1];
            size -= 1;
        } else {
            move_index += 1;
        }
    }
    return size;
}

fn isLegalGeneratedMove(self: *Board, move: Move, pinned_bb: u64) bool {
    const king_bb = self.piece_bitboards[@enumToInt(Piece.Type.King)];
    const side_to_move = self.side_to_move;
    const color_bb = self.color_bitboards[@enumToInt(side_to_move)];
    const other_color_bb = self.color_bitboards[@enumToInt(side_to_move.reverse())];
    const king_square = @intToEnum(Square, bitboard.bitscanForward(king_bb & color_bb));

    const from_square = move.from_square;
    const to_square = move.to_square;
    if (self.pieceTypeOn(from_square) == .Pawn and to_square == self.enpassant_square) {
        const enpassant_bb = self.enpassant_square.toBitboard();
        const post_enpassant_occupancy_bb = (self.occupancyBB() ^
            from_square.toBitboard() ^
            (if (side_to_move == .White) enpassant_bb >> 8 else enpassant_bb << 8)) | enpassant_bb;
        return (attacks.bishopAttacks(king_square, post_enpassant_occupancy_bb) & (self.piece_bitboards[@enumToInt(Piece.Type.Queen)] | self.piece_bitboards[@enumToInt(Piece.Type.Bishop)]) & other_color_bb) == 0 and
            (attacks.rookAttacks(king_square, post_enpassant_occupancy_bb) & (self.piece_bitboards[@enumToInt(Piece.Type.Queen)] | self.piece_bitboards[@enumToInt(Piece.Type.Rook)]) & other_color_bb) == 0;
    } else if (from_square == king_square) {
        return (to_square.toBitboard() & attacks.kingAttacks(king_square)) == 0 or (self.attackersBBToSquare(to_square, self.occupancyBB()) & other_color_bb) == 0;
    } else {
        return (pinned_bb & from_square.toBitboard()) == 0 or
            (to_square.toBitboard() & masks.xray_masks[@enumToInt(king_square)][@enumToInt(from_square)]) != 0;
    }
}

fn generateCheckEvasions(self: *Board, move_list_iterator: *MoveList.Iterator) void {
    const side_to_move = self.side_to_move;
    assert(self.sideIsInCheck(side_to_move));

    const king_bb = self.piece_bitboards[@enumToInt(Piece.Type.King)];
    const color_bb = self.color_bitboards[@enumToInt(side_to_move)];
    const color_king_bb = king_bb & color_bb;
    const king_square = @intToEnum(Square, bitboard.bitscanForward(color_king_bb));
    const checkers_bb = self.checkersBBToColor(side_to_move);
    const sans_king_occupancy_bb = self.occupancyBB() ^ king_square.toBitboard();
    var evasions_bb = attacks.kingAttacks(king_square) & ~color_bb;
    const other_color_bb = self.color_bitboards[@enumToInt(side_to_move.reverse())];
    while (evasions_bb != 0) {
        const square = @intToEnum(Square, bitboard.bitscanForward(evasions_bb));
        bitboard.popBitForward(&evasions_bb);
        if ((self.attackersBBToSquare(square, sans_king_occupancy_bb) & other_color_bb) == 0) {
            move_list_iterator.addMove(Move{
                .from_square = king_square,
                .to_square = square,
            });
        }
    }

    if ((checkers_bb & (checkers_bb - 1)) != 0) {
        return;
    }

    const pawns_bb = self.piece_bitboards[@enumToInt(Piece.Type.Pawn)] & color_bb;
    const enpassant_square = self.enpassant_square;
    if (side_to_move == .White) {
        if (enpassant_square != .None and ((enpassant_square.toBitboard() >> 8) & checkers_bb) != 0) {
            var enpassant_candidates_bb = attacks.pawnAttacks(enpassant_square, Color.Black) & pawns_bb;
            while (enpassant_candidates_bb != 0) {
                const from_square = @intToEnum(Square, bitboard.bitscanForward(enpassant_candidates_bb));
                bitboard.popBitForward(&enpassant_candidates_bb);
                move_list_iterator.addMove(Move{
                    .from_square = from_square,
                    .to_square = enpassant_square,
                });
            }
        }
    } else {
        if (enpassant_square != .None and ((enpassant_square.toBitboard() << 8) & checkers_bb) != 0) {
            var enpassant_candidates_bb = attacks.pawnAttacks(enpassant_square, Color.White) & pawns_bb;
            while (enpassant_candidates_bb != 0) {
                const from_square = @intToEnum(Square, bitboard.bitscanForward(enpassant_candidates_bb));
                bitboard.popBitForward(&enpassant_candidates_bb);
                move_list_iterator.addMove(Move{
                    .from_square = from_square,
                    .to_square = enpassant_square,
                });
            }
        }
    }

    const checker_square = @intToEnum(Square, bitboard.bitscanForward(checkers_bb));
    const occupancy_bb = self.occupancyBB();
    var attackers_bb = self.attackersBBToSquare(checker_square, occupancy_bb) & color_bb & ~color_king_bb;
    const rank_7_pawns = pawns_bb & (if (side_to_move == .White) masks.rank_masks[@enumToInt(Rank.Seven)] else masks.rank_masks[@enumToInt(Rank.Two)]);
    var pawn_promotion_attackers_bb = attackers_bb & rank_7_pawns;
    attackers_bb &= ~rank_7_pawns;
    while (pawn_promotion_attackers_bb != 0) {
        const from_square = @intToEnum(Square, bitboard.bitscanForward(pawn_promotion_attackers_bb));
        bitboard.popBitForward(&pawn_promotion_attackers_bb);
        for ([_]Piece.Type{ .Queen, .Knight, .Bishop, .Rook }) |piece_type| {
            move_list_iterator.addMove(Move{
                .from_square = from_square,
                .to_square = checker_square,
                .promotion_piece_type = piece_type,
            });
        }
    }
    while (attackers_bb != 0) {
        const from_square = @intToEnum(Square, bitboard.bitscanForward(attackers_bb));
        bitboard.popBitForward(&attackers_bb);
        move_list_iterator.addMove(Move{
            .from_square = from_square,
            .to_square = checker_square,
        });
    }

    if ((checkers_bb & attacks.kingAttacks(king_square)) != 0) {
        return;
    }

    var checker_intercept_bb = masks.intervening_masks[@enumToInt(king_square)][@enumToInt(checker_square)];
    if (checker_intercept_bb == 0) {
        return;
    }

    if (side_to_move == .White) {
        const shifted_intercept_bb = checker_intercept_bb >> 8;
        var single_push_pawn_blockers_bb = pawns_bb & shifted_intercept_bb;
        var double_push_pawn_blockers_bb = ((shifted_intercept_bb & ~occupancy_bb) >> 8) & pawns_bb & masks.rank_masks[@enumToInt(Rank.Two)];
        while (double_push_pawn_blockers_bb != 0) {
            const from_square = @intToEnum(Square, bitboard.bitscanForward(double_push_pawn_blockers_bb));
            bitboard.popBitForward(&double_push_pawn_blockers_bb);
            move_list_iterator.addMove(Move{
                .from_square = from_square,
                .to_square = @intToEnum(Square, @enumToInt(from_square) + 16),
            });
        }
        while (single_push_pawn_blockers_bb != 0) {
            const from_square = @intToEnum(Square, bitboard.bitscanForward(single_push_pawn_blockers_bb));
            bitboard.popBitForward(&single_push_pawn_blockers_bb);
            const to_square = @intToEnum(Square, @enumToInt(from_square) + 8);
            if ((to_square.toBitboard() & masks.rank_masks[@enumToInt(Rank.Seven)]) != 0) {
                for ([_]Piece.Type{ .Queen, .Knight, .Bishop, .Rook }) |piece_type| {
                    move_list_iterator.addMove(Move{
                        .from_square = from_square,
                        .to_square = to_square,
                        .promotion_piece_type = piece_type,
                    });
                }
            } else {
                move_list_iterator.addMove(Move{
                    .from_square = from_square,
                    .to_square = to_square,
                });
            }
        }
    } else {
        const shifted_intercept_bb = checker_intercept_bb << 8;
        var single_push_pawn_blockers_bb = pawns_bb & shifted_intercept_bb;
        var double_push_pawn_blockers_bb = ((shifted_intercept_bb & ~occupancy_bb) << 8) & pawns_bb & masks.rank_masks[@enumToInt(Rank.Seven)];
        while (double_push_pawn_blockers_bb != 0) {
            const from_square = @intToEnum(Square, bitboard.bitscanForward(double_push_pawn_blockers_bb));
            bitboard.popBitForward(&double_push_pawn_blockers_bb);
            move_list_iterator.addMove(Move{
                .from_square = from_square,
                .to_square = @intToEnum(Square, @enumToInt(from_square) - 16),
            });
        }
        while (single_push_pawn_blockers_bb != 0) {
            const from_square = @intToEnum(Square, bitboard.bitscanForward(single_push_pawn_blockers_bb));
            bitboard.popBitForward(&single_push_pawn_blockers_bb);
            const to_square = @intToEnum(Square, @enumToInt(from_square) - 8);
            if ((to_square.toBitboard() & masks.rank_masks[@enumToInt(Rank.Two)]) != 0) {
                for ([_]Piece.Type{ .Queen, .Knight, .Bishop, .Rook }) |piece_type| {
                    move_list_iterator.addMove(Move{
                        .from_square = from_square,
                        .to_square = to_square,
                        .promotion_piece_type = piece_type,
                    });
                }
            } else {
                move_list_iterator.addMove(Move{
                    .from_square = from_square,
                    .to_square = to_square,
                });
            }
        }
    }

    const excluded_piece_types_mask = ~(king_bb | pawns_bb);
    while (checker_intercept_bb != 0) {
        const to_square = @intToEnum(Square, bitboard.bitscanForward(checker_intercept_bb));
        bitboard.popBitForward(&checker_intercept_bb);
        var blockers_bb = self.attackersBBToSquare(to_square, occupancy_bb) & color_bb & excluded_piece_types_mask;
        while (blockers_bb != 0) {
            const from_square = @intToEnum(Square, bitboard.bitscanForward(blockers_bb));
            bitboard.popBitForward(&blockers_bb);
            move_list_iterator.addMove(Move{
                .from_square = from_square,
                .to_square = to_square,
            });
        }
    }
}

fn generatePseudolegalMoves(self: *Board, move_list_iterator: *MoveList.Iterator) void {
    self.generateNonPawnMoves(move_list_iterator);
    self.generatePawnMoves(move_list_iterator);
}

fn generateNonPawnMoves(self: *Board, move_list_iterator: *MoveList.Iterator) void {
    const side_to_move_occupancy_bb = self.color_bitboards[@enumToInt(self.side_to_move)];
    const other_side_occupancy_bb = self.color_bitboards[@enumToInt(self.side_to_move.reverse())];
    const occupancy_bb = side_to_move_occupancy_bb | other_side_occupancy_bb;

    for ([_]Piece.Type{ .Knight, .Bishop, .Rook, .Queen, .King }) |piece_type| {
        var piece_type_bb = self.piece_bitboards[@enumToInt(piece_type)] & self.color_bitboards[@enumToInt(self.side_to_move)];
        while (piece_type_bb != 0) {
            const from_square = @intToEnum(Square, bitboard.bitscanForward(piece_type_bb));
            bitboard.popBitForward(&piece_type_bb);

            var attacks_bb = attacks.nonPawnAttacks(piece_type, from_square, occupancy_bb) & (~side_to_move_occupancy_bb | other_side_occupancy_bb);
            while (attacks_bb != 0) {
                const to_square = @intToEnum(Square, bitboard.bitscanForward(attacks_bb));
                bitboard.popBitForward(&attacks_bb);
                move_list_iterator.*.addMove(Move{
                    .from_square = from_square,
                    .to_square = to_square,
                });
            }
        }
    }
    self.generateCastlingMoves(move_list_iterator);
}

fn generateCastlingMoves(self: *Board, move_list_iterator: *MoveList.Iterator) void {
    const castling_possibilities = [2][2]u4{
        [2]u4{ 1, 2 },
        [2]u4{ 4, 8 },
    };
    const castling_mask = [2][2]u64{
        [2]u64{
            Square.F1.toBitboard() | Square.G1.toBitboard(),
            Square.D1.toBitboard() | Square.C1.toBitboard() | Square.B1.toBitboard(),
        },
        [2]u64{
            Square.F8.toBitboard() | Square.G8.toBitboard(),
            Square.D8.toBitboard() | Square.C8.toBitboard() | Square.B8.toBitboard(),
        },
    };
    const castling_intermediate_squares = [2][2][2]Square{
        [2][2]Square{
            [2]Square{ Square.F1, Square.G1 },
            [2]Square{ Square.D1, Square.C1 },
        },
        [2][2]Square{
            [2]Square{ Square.F8, Square.G8 },
            [2]Square{ Square.D8, Square.C8 },
        },
    };
    const castling_king_squares = [2][2][2]Square{
        [2][2]Square{
            [2]Square{ Square.E1, Square.G1 },
            [2]Square{ Square.E1, Square.C1 },
        },
        [2][2]Square{
            [2]Square{ Square.E8, Square.G8 },
            [2]Square{ Square.E8, Square.C8 },
        },
    };

    const castling_rights = self.castling_rights_bitset;
    const side_to_move = @enumToInt(self.side_to_move);
    const occupancy_bb = self.occupancyBB();
    if ((castling_possibilities[side_to_move][0] & castling_rights) != 0 and
        ((castling_mask[side_to_move][0] & occupancy_bb) == 0) and
        (self.checkersBBToColor(@intToEnum(Color, side_to_move)) == 0) and
        (self.attackersBBToSquareByColor(castling_intermediate_squares[side_to_move][0][0], @intToEnum(Color, side_to_move ^ 1)) == 0) and
        (self.attackersBBToSquareByColor(castling_intermediate_squares[side_to_move][0][1], @intToEnum(Color, side_to_move ^ 1)) == 0))
    {
        move_list_iterator.addMove(Move{
            .from_square = castling_king_squares[side_to_move][0][0],
            .to_square = castling_king_squares[side_to_move][0][1],
        });
    }
    if ((castling_possibilities[side_to_move][1] & castling_rights) != 0 and
        ((castling_mask[side_to_move][1] & occupancy_bb) == 0) and
        (self.checkersBBToColor(@intToEnum(Color, side_to_move)) == 0) and
        (self.attackersBBToSquareByColor(castling_intermediate_squares[side_to_move][1][0], @intToEnum(Color, side_to_move ^ 1)) == 0) and
        (self.attackersBBToSquareByColor(castling_intermediate_squares[side_to_move][1][1], @intToEnum(Color, side_to_move ^ 1)) == 0))
    {
        move_list_iterator.addMove(Move{
            .from_square = castling_king_squares[side_to_move][1][0],
            .to_square = castling_king_squares[side_to_move][1][1],
        });
    }
}

fn generatePawnMoves(self: *Board, move_list_iterator: *MoveList.Iterator) void {
    const white_bb = self.color_bitboards[@enumToInt(Color.White)];
    const black_bb = self.color_bitboards[@enumToInt(Color.Black)];
    const occupancy_bb = white_bb | black_bb;

    if (self.side_to_move == Color.White) {
        const pawn_bb = self.piece_bitboards[@enumToInt(Piece.Type.Pawn)] & white_bb;
        var single_push_bb = (pawn_bb << 8) & ~occupancy_bb;
        var double_push_bb = ((single_push_bb & masks.rank_masks[@enumToInt(Rank.Three)]) << 8) & ~occupancy_bb;
        var nw_capture_bb = ((pawn_bb << 7) & black_bb) & ~masks.file_masks[@enumToInt(File.H)];
        var ne_capture_bb = ((pawn_bb << 9) & black_bb) & ~masks.file_masks[@enumToInt(File.A)];

        const rank_8_mask = masks.rank_masks[@enumToInt(Rank.Eight)];
        const sans_rank_8_mask = ~rank_8_mask;

        var push_promotions_bb = single_push_bb & rank_8_mask;
        var nw_capture_promotions_bb = nw_capture_bb & rank_8_mask;
        var ne_capture_promotions_bb = ne_capture_bb & rank_8_mask;

        single_push_bb &= sans_rank_8_mask;
        nw_capture_bb &= sans_rank_8_mask;
        ne_capture_bb &= sans_rank_8_mask;

        const enpassant_square = self.enpassant_square;
        if (enpassant_square != .None) {
            var enpassant_candidates_bb = attacks.pawnAttacks(enpassant_square, Color.Black) & pawn_bb;
            while (enpassant_candidates_bb != 0) {
                const from_square = @intToEnum(Square, bitboard.bitscanForward(enpassant_candidates_bb));
                bitboard.popBitForward(&enpassant_candidates_bb);
                move_list_iterator.*.addMove(Move{
                    .from_square = from_square,
                    .to_square = enpassant_square,
                });
            }
        }

        while (single_push_bb != 0) {
            const to_square = @intToEnum(Square, bitboard.bitscanForward(single_push_bb));
            bitboard.popBitForward(&single_push_bb);
            move_list_iterator.*.addMove(Move{
                .from_square = @intToEnum(Square, @enumToInt(to_square) - 8),
                .to_square = to_square,
            });
        }
        while (double_push_bb != 0) {
            const to_square = @intToEnum(Square, bitboard.bitscanForward(double_push_bb));
            bitboard.popBitForward(&double_push_bb);
            move_list_iterator.*.addMove(Move{
                .from_square = @intToEnum(Square, @enumToInt(to_square) - 16),
                .to_square = to_square,
            });
        }
        while (nw_capture_bb != 0) {
            const to_square = @intToEnum(Square, bitboard.bitscanForward(nw_capture_bb));
            bitboard.popBitForward(&nw_capture_bb);
            move_list_iterator.*.addMove(Move{
                .from_square = @intToEnum(Square, @enumToInt(to_square) - 7),
                .to_square = to_square,
            });
        }
        while (ne_capture_bb != 0) {
            const to_square = @intToEnum(Square, bitboard.bitscanForward(ne_capture_bb));
            bitboard.popBitForward(&ne_capture_bb);
            move_list_iterator.*.addMove(Move{
                .from_square = @intToEnum(Square, @enumToInt(to_square) - 9),
                .to_square = to_square,
            });
        }
        while (push_promotions_bb != 0) {
            const to_square = @intToEnum(Square, bitboard.bitscanForward(push_promotions_bb));
            bitboard.popBitForward(&push_promotions_bb);
            for ([_]Piece.Type{ .Queen, .Knight, .Bishop, .Rook }) |piece_type| {
                move_list_iterator.*.addMove(Move{
                    .from_square = @intToEnum(Square, @enumToInt(to_square) - 8),
                    .to_square = to_square,
                    .promotion_piece_type = piece_type,
                });
            }
        }
        while (nw_capture_promotions_bb != 0) {
            const to_square = @intToEnum(Square, bitboard.bitscanForward(nw_capture_promotions_bb));
            bitboard.popBitForward(&nw_capture_promotions_bb);
            for ([_]Piece.Type{ .Queen, .Knight, .Bishop, .Rook }) |piece_type| {
                move_list_iterator.*.addMove(Move{
                    .from_square = @intToEnum(Square, @enumToInt(to_square) - 7),
                    .to_square = to_square,
                    .promotion_piece_type = piece_type,
                });
            }
        }
        while (ne_capture_promotions_bb != 0) {
            const to_square = @intToEnum(Square, bitboard.bitscanForward(ne_capture_promotions_bb));
            bitboard.popBitForward(&ne_capture_promotions_bb);
            for ([_]Piece.Type{ .Queen, .Knight, .Bishop, .Rook }) |piece_type| {
                move_list_iterator.*.addMove(Move{
                    .from_square = @intToEnum(Square, @enumToInt(to_square) - 9),
                    .to_square = to_square,
                    .promotion_piece_type = piece_type,
                });
            }
        }
    } else {
        const pawn_bb = self.piece_bitboards[@enumToInt(Piece.Type.Pawn)] & black_bb;
        var single_push_bb = (pawn_bb >> 8) & ~occupancy_bb;
        var double_push_bb = ((single_push_bb & masks.rank_masks[@enumToInt(Rank.Six)]) >> 8) & ~occupancy_bb;
        var se_capture_bb = ((pawn_bb >> 7) & white_bb) & ~masks.file_masks[@enumToInt(File.A)];
        var sw_capture_bb = ((pawn_bb >> 9) & white_bb) & ~masks.file_masks[@enumToInt(File.H)];

        const rank_1_mask = masks.rank_masks[@enumToInt(Rank.One)];
        const sans_rank_1_mask = ~rank_1_mask;

        var push_promotions_bb = single_push_bb & rank_1_mask;
        var se_capture_promotions_bb = se_capture_bb & rank_1_mask;
        var sw_capture_promotions_bb = sw_capture_bb & rank_1_mask;

        single_push_bb &= sans_rank_1_mask;
        se_capture_bb &= sans_rank_1_mask;
        sw_capture_bb &= sans_rank_1_mask;

        const enpassant_square = self.enpassant_square;
        if (enpassant_square != .None) {
            var enpassant_candidates_bb = attacks.pawnAttacks(enpassant_square, Color.White) & pawn_bb;
            while (enpassant_candidates_bb != 0) {
                const from_square = @intToEnum(Square, bitboard.bitscanForward(enpassant_candidates_bb));
                bitboard.popBitForward(&enpassant_candidates_bb);
                move_list_iterator.*.addMove(Move{
                    .from_square = from_square,
                    .to_square = enpassant_square,
                });
            }
        }

        while (single_push_bb != 0) {
            const to_square = @intToEnum(Square, bitboard.bitscanForward(single_push_bb));
            bitboard.popBitForward(&single_push_bb);
            move_list_iterator.*.addMove(Move{
                .from_square = @intToEnum(Square, @enumToInt(to_square) + 8),
                .to_square = to_square,
            });
        }
        while (double_push_bb != 0) {
            const to_square = @intToEnum(Square, bitboard.bitscanForward(double_push_bb));
            bitboard.popBitForward(&double_push_bb);
            move_list_iterator.*.addMove(Move{
                .from_square = @intToEnum(Square, @enumToInt(to_square) + 16),
                .to_square = to_square,
            });
        }
        while (se_capture_bb != 0) {
            const to_square = @intToEnum(Square, bitboard.bitscanForward(se_capture_bb));
            bitboard.popBitForward(&se_capture_bb);
            move_list_iterator.*.addMove(Move{
                .from_square = @intToEnum(Square, @enumToInt(to_square) + 7),
                .to_square = to_square,
            });
        }
        while (sw_capture_bb != 0) {
            const to_square = @intToEnum(Square, bitboard.bitscanForward(sw_capture_bb));
            bitboard.popBitForward(&sw_capture_bb);
            move_list_iterator.*.addMove(Move{
                .from_square = @intToEnum(Square, @enumToInt(to_square) + 9),
                .to_square = to_square,
            });
        }
        while (push_promotions_bb != 0) {
            const to_square = @intToEnum(Square, bitboard.bitscanForward(push_promotions_bb));
            bitboard.popBitForward(&push_promotions_bb);
            for ([_]Piece.Type{ .Queen, .Knight, .Bishop, .Rook }) |piece_type| {
                move_list_iterator.*.addMove(Move{
                    .from_square = @intToEnum(Square, @enumToInt(to_square) + 8),
                    .to_square = to_square,
                    .promotion_piece_type = piece_type,
                });
            }
        }
        while (se_capture_promotions_bb != 0) {
            const to_square = @intToEnum(Square, bitboard.bitscanForward(se_capture_promotions_bb));
            bitboard.popBitForward(&se_capture_promotions_bb);
            for ([_]Piece.Type{ .Queen, .Knight, .Bishop, .Rook }) |piece_type| {
                move_list_iterator.*.addMove(Move{
                    .from_square = @intToEnum(Square, @enumToInt(to_square) + 7),
                    .to_square = to_square,
                    .promotion_piece_type = piece_type,
                });
            }
        }
        while (sw_capture_promotions_bb != 0) {
            const to_square = @intToEnum(Square, bitboard.bitscanForward(sw_capture_promotions_bb));
            bitboard.popBitForward(&sw_capture_promotions_bb);
            for ([_]Piece.Type{ .Queen, .Knight, .Bishop, .Rook }) |piece_type| {
                move_list_iterator.*.addMove(Move{
                    .from_square = @intToEnum(Square, @enumToInt(to_square) + 9),
                    .to_square = to_square,
                    .promotion_piece_type = piece_type,
                });
            }
        }
    }
}

fn moveTypeOf(self: *Board, move: Move) Move.Type {
    const to = move.to_square;
    const from = move.from_square;
    const moving_piece_type = self.pieceTypeOn(from);
    const captured_piece_type = self.pieceTypeOn(to);
    const promotion_piece_type = move.promotion_piece_type;

    if (promotion_piece_type != .None) {
        return if (captured_piece_type != .None) .CapturePromotion else .Promotion;
    } else if (captured_piece_type != .None) {
        return .Capture;
    } else if (moving_piece_type == Piece.Type.Pawn) {
        const square_diff = std.math.absCast(@intCast(i32, @enumToInt(to)) - @intCast(i32, @enumToInt(from)));
        if (square_diff == 16) {
            return .DoublePush;
        } else if (to == self.enpassant_square) {
            return .Enpassant;
        } else {
            return .Normal;
        }
    } else if (moving_piece_type == Piece.Type.King and std.math.absCast(@intCast(i32, @enumToInt(to)) - @intCast(i32, @enumToInt(from))) == 2) {
        return .Castling;
    } else {
        return .Normal;
    }
}

inline fn movePiece(self: *Board, piece: Piece, from: Square, to: Square) void {
    const from_to_bb = from.toBitboard() | to.toBitboard();

    self.piece_bitboards[@enumToInt(piece.type)] ^= from_to_bb;
    self.color_bitboards[@enumToInt(piece.color)] ^= from_to_bb;
}

inline fn putPiece(self: *Board, piece: Piece, square: Square) void {
    const to_bb = square.toBitboard();

    self.piece_bitboards[@enumToInt(piece.type)] ^= to_bb;
    self.color_bitboards[@enumToInt(piece.color)] ^= to_bb;
}

inline fn removePiece(self: *Board, piece: Piece, square: Square) void {
    const from_bb = square.toBitboard();

    self.piece_bitboards[@enumToInt(piece.type)] ^= from_bb;
    self.color_bitboards[@enumToInt(piece.color)] ^= from_bb;
}
