const Piece = @This();

const std = @import("std");

const Color = @import("enums.zig").Color;

type: Type = undefined,
color: Color = undefined,

pub inline fn parse(ch: u8) Piece {
    return switch (ch) {
        'P' => Piece{ .type = .Pawn, .color = .White },
        'p' => Piece{ .type = .Pawn, .color = .Black },
        'N' => Piece{ .type = .Knight, .color = .White },
        'n' => Piece{ .type = .Knight, .color = .Black },
        'B' => Piece{ .type = .Bishop, .color = .White },
        'b' => Piece{ .type = .Bishop, .color = .Black },
        'R' => Piece{ .type = .Rook, .color = .White },
        'r' => Piece{ .type = .Rook, .color = .Black },
        'Q' => Piece{ .type = .Queen, .color = .White },
        'q' => Piece{ .type = .Queen, .color = .Black },
        'K' => Piece{ .type = .King, .color = .White },
        'k' => Piece{ .type = .King, .color = .Black },
        else => unreachable,
    };
}

pub inline fn toChar(self: Piece) u8 {
    const piece_type_char = self.type.toChar();
    return if (self.color == Color.White) std.ascii.toUpper(piece_type_char) else piece_type_char;
}

pub const Type = enum(u3) {
    Pawn,
    Knight,
    Bishop,
    Rook,
    Queen,
    King,
    None,
    _,

    pub const all = [6]Piece.Type{ .Pawn, .Knight, .Bishop, .Rook, .Queen, .King };

    pub inline fn parse(ch: u8) Piece.Type {
        return switch (ch) {
            'p' => .Pawn,
            'n' => .Knight,
            'b' => .Bishop,
            'r' => .Rook,
            'q' => .Queen,
            'k' => .King,
            else => unreachable,
        };
    }

    pub inline fn toChar(self: Piece.Type) u8 {
        return switch (self) {
            .Pawn => 'p',
            .Knight => 'n',
            .Bishop => 'b',
            .Rook => 'r',
            .Queen => 'q',
            .King => 'k',
            else => unreachable,
        };
    }
};
