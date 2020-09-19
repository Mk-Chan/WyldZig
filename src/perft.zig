const std = @import("std");

const Board = @import("types/Board.zig");
const Move = @import("types/Move.zig");
const MoveList = @import("types/MoveList.zig");

//const console = @import("utils/console.zig");

pub fn perft(board: *Board, depth: usize, root: bool) u64 {
    var leaf_count: u64 = 0;

    var move_list = MoveList{};
    var move_list_iterator = MoveList.Iterator{ .iter = &move_list.list };
    const num_moves = board.generateLegalMoves(&move_list_iterator);

    if (depth == 1) {
        return num_moves;
    }

    if (root) {
        comptime const num_threads: usize = 8;
        var results = [_]u64{0} ** num_threads;
        var move_num = std.atomic.Int(usize).init(0);
        var perft_data = PerftData{
            .board = board,
            .remaining_depth = depth - 1,
            .move_list = &move_list.list,
            .num_moves = num_moves,
            .move_num = &move_num,
            .results = &results,
        };

        var threads: [num_threads]*std.Thread = undefined;
        var thread_num: usize = 0;
        while (thread_num < num_threads) : (thread_num += 1) {
            var thread_data = ThreadData{
                .thread_index = thread_num,
                .perft_data = &perft_data,
            };
            threads[thread_num] = std.Thread.spawn(thread_data, getAndPerftMove) catch |err| {
                unreachable;
            };
        }

        thread_num = 0;
        while (thread_num < num_threads) : (thread_num += 1) {
            threads[thread_num].wait();
            leaf_count += perft_data.results[thread_num];
        }
    } else {
        var move_num: usize = 0;
        while (move_num < num_moves) {
            const move = move_list.list[move_num];
            move_num += 1;

            var child = board.*;
            child.makeMove(move);
            //var old_leaf_count = leaf_count;
            leaf_count += perft(&child, depth - 1, false);

            //if (root) {
            //    console.println("Move: {}, Nodes: {}", .{ move.toString(), leaf_count - old_leaf_count });
            //}
        }
    }
    return leaf_count;
}

fn getAndPerftMove(context: ThreadData) void {
    var perft_data = context.perft_data;
    var leaf_count: u64 = 0;
    while (true) {
        const next_move_index = perft_data.move_num.fetchAdd(1);
        if (next_move_index >= perft_data.num_moves) {
            break;
        }
        const move = perft_data.move_list[next_move_index];
        var child = perft_data.board.*;
        child.makeMove(move);
        leaf_count += perft(&child, perft_data.remaining_depth, false);
    }
    perft_data.results[context.thread_index] = leaf_count;
}

const PerftData = struct {
    board: *Board,
    remaining_depth: usize,
    move_list: [*]Move,
    num_moves: usize,
    move_num: *std.atomic.Int(usize),
    results: [*]u64,
};

const ThreadData = struct {
    thread_index: usize,
    perft_data: *PerftData,
};
