const Move = @This();

const Piece = @import("Piece.zig");
const Square = @import("enums.zig").Square;

from_square: Square = undefined,
to_square: Square = undefined,
promotion_piece_type: Piece.Type = .None,

pub fn parse(move_str: []const u8) ?Move {
    const len = move_str.len;
    if (len < 4 or len > 5) {
        return null;
    }
    var move = Move{
        .from_square = Square.parse(move_str[0..2]),
        .to_square = Square.parse(move_str[2..4]),
        .promotion_piece_type = .None,
    };
    if (len == 5) {
        move.promotion_piece_type = Piece.Type.parse(move_str[4]);
    }
    return move;
}

pub fn toString(self: Move) [6:0]u8 {
    const from_square_string = self.from_square.toString();
    const to_square_string = self.to_square.toString();
    return [6:0]u8{
        from_square_string[0],
        from_square_string[1],
        to_square_string[0],
        to_square_string[1],
        if (self.promotion_piece_type != .None) self.promotion_piece_type.toChar() else 0,
        0,
    };
}

pub const Type = enum(u3) {
    None,
    Normal,
    Capture,
    DoublePush,
    Enpassant,
    Castling,
    CapturePromotion,
    Promotion,
};
