const MoveList = @This();

const Move = @import("Move.zig");

list: [218]Move = undefined,

pub const Iterator = struct {
    iter: [*]Move,

    pub fn addMove(self: *Iterator, move: Move) void {
        self.*.iter.* = move;
        self.*.iter += 1;
    }
};
