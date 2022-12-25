const std = @import("std");

const console = @import("utils/console.zig");
const string = @import("utils/string.zig");

const attacks = @import("bitboards/attacks.zig");
const masks = @import("bitboards/masks.zig");

const MoveList = @import("types/MoveList.zig");
const Square = @import("types/enums.zig").Square;
const Board = @import("types/Board.zig");
const Piece = @import("types/Piece.zig");
const Move = @import("types/Move.zig");

const perft = @import("perft.zig");

const SearchParamters = struct {
    movetime: u32,
};

const SearchGlobals = struct {
    start_time: u32,
    end_time: u32,

    lock: std.Mutex,
    stop: bool,
};

fn uciIntroduction() void {
    console.println("id name WyldZig", .{});
    console.println("id author Manik Charan", .{});
}

pub fn uci() void {
    uciIntroduction();

    var board: Board = Board.parse("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");

    var input_buffer: [2048]u8 = undefined;
    while (true) {
        const line = console.readln(input_buffer[0..]);
        if (string.equals(line, "quit")) {
            break;
        } else if (string.startsWith(line, "position")) {
            if (line.len < 10) {
                console.println("Invalid position command!", .{});
                continue;
            }
            const remaining = line[9..];
            if (string.equals(remaining, "startpos")) {
                board = Board.parse("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
            } else if (string.startsWith(remaining, "fen")) {
                if (remaining.len < 5) {
                    console.println("Invalid position command!", .{});
                    continue;
                }
                board = Board.parse(remaining[4..]);
            } else {
                console.println("Invalid position command!", .{});
            }
        } else if (string.equals(line, "d")) {
            board.print();
        } else if (string.startsWith(line, "perft")) {
            if (line.len < 7) {
                console.println("Invalid perft command!", .{});
                continue;
            }
            const remaining = line[6..];
            const depth = std.fmt.parseInt(usize, remaining, 10) catch unreachable;

            const start_time = std.time.milliTimestamp();
            const leafCount = perft.perft(&board, depth, true);
            const end_time = std.time.milliTimestamp();

            console.println("info depth {} time {} nodes: {}", .{ depth, end_time - start_time, leafCount });
        } else if (string.startsWith(line, "move")) {
            if (line.len < 6) {
                console.println("Invalid move command!", .{});
                continue;
            }
            const remaining = line[5..];
            const parsed_move = Move.parse(remaining);
            if (parsed_move) |move| {
                board.makeMove(move);
            } else {
                console.println("Invalid move: {s}", .{remaining});
            }
        } else {
            console.println("Unsupported command: {s}", .{line});
        }
    }
}
