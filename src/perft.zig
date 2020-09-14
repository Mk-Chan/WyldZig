const Board = @import("types/Board.zig");
const Move = @import("types/Move.zig");
const MoveList = @import("types/MoveList.zig");

pub fn perft(board: *Board, depth: usize, root: bool) u64 {
    var leaf_count: u64 = 0;

    var move_list = MoveList{};
    var move_list_iterator = MoveList.Iterator{ .iter = &move_list.list };
    const numMoves = board.generateLegalMoves(&move_list_iterator);

    if (depth == 1) {
        return numMoves;
    }

    var moveNum: u8 = 0;
    while (moveNum < numMoves) {
        const move = move_list.list[moveNum];
        moveNum += 1;

        var child = board.*;
        child.makeMove(move);
        //var old_leaf_count = leaf_count;
        leaf_count += perft(&child, depth - 1, false);

        //if (root) {
        //    console.println("Move: {}, Nodes: {}", .{ move.toString(), leaf_count - old_leaf_count });
        //}
    }
    return leaf_count;
}
