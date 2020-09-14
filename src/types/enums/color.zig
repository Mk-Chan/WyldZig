pub const Color = enum(u1) {
    White,
    Black,

    pub const all = [2]Color{ .White, .Black };

    pub inline fn reverse(self: Color) Color {
        return if (self == Color.White) Color.Black else Color.White;
    }

    pub inline fn parse(ch: u8) Color {
        return if (ch == 'w') Color.White else Color.Black;
    }

    pub inline fn toChar(self: Color) u8 {
        return if (self == Color.White) 'w' else 'b';
    }
};
