const console = @import("utils/console.zig");
const string = @import("utils/string.zig");

const attacks = @import("bitboards/attacks.zig");

const uci = @import("uci.zig");

pub fn main() void {
    console.println("WyldZig by Manik Charan", .{});
    var input_buffer: [2048]u8 = undefined;
    while (true) {
        const line = console.readln(input_buffer[0..]) orelse break;
        if (string.equals(line, "uci")) {
            uci.uci();
            break;
        } else if (string.equals(line, "quit")) {
            break;
        } else {
            console.println("Unsupported command: {}. Expected uci!", .{line});
        }
    }
}
