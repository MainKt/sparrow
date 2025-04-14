const std = @import("std");
const lib = @import("sparrow_lib");

const input = @cImport({
    @cInclude("linux/input.h");
});

fn syncronize(fd: std.posix.fd_t) void {
    _ = std.posix.system.write(
        fd,
        @ptrCast(&input.input_event{
            .type = input.EV_SYN,
            .code = input.SYN_REPORT,
            .value = 0,
        }),
        @sizeOf(input.input_event),
    );
}

fn mouse_click(fd: std.posix.fd_t, button: enum(u16) {
    left = input.BTN_LEFT,
    right = input.BTN_RIGHT,
    middle = input.BTN_MIDDLE,
}) void {
    _ = std.posix.system.write(
        fd,
        @ptrCast(&input.input_event{
            .type = input.EV_KEY,
            .code = @intFromEnum(button),
            .value = 1,
        }),
        @sizeOf(input.input_event),
    );

    _ = std.posix.system.write(
        fd,
        @ptrCast(&input.input_event{
            .type = input.EV_KEY,
            .code = @intFromEnum(button),
            .value = 0,
        }),
        @sizeOf(input.input_event),
    );
}

fn move_mouse(fd: std.posix.fd_t, delta: struct {
    x: i32,
    y: i32,
}) void {
    _ = std.posix.system.write(
        fd,
        @ptrCast(&input.input_event{
            .type = input.EV_REL,
            .code = input.REL_X,
            .value = delta.x,
        }),
        @sizeOf(input.input_event),
    );

    _ = std.posix.system.write(
        fd,
        @ptrCast(&input.input_event{
            .type = input.EV_REL,
            .code = input.REL_Y,
            .value = delta.y,
        }),
        @sizeOf(input.input_event),
    );
}

pub fn main() !void {
    const args = std.os.argv;
    if (args.len == 1)
        return error.NO_INPUT_DEVICE_PROVIDED;
    if (args.len > 2)
        return error.INVALID_ARGS;

    const device_name: []u8 = std.mem.span(args[1]);
    const device = try std.fs.openFileAbsolute(device_name, .{
        .mode = .read_only,
    });
    defer device.close();
    std.debug.print("Listening on {s}...\n", .{device_name});

    const daemon_socket = try std.posix.socket(
        std.posix.AF.UNIX,
        std.posix.SOCK.DGRAM,
        0,
    );

    const env_xrd = std.posix.getenv("XDG_RUNTIME_DIR");
    const socket_path = try std.fmt.bufPrint(
        blk: {
            var buf: [108]u8 = undefined;
            break :blk &buf;
        },
        "{s}/.sparrow_socket",
        .{env_xrd orelse "/tmp"},
    );

    const address = try std.net.Address.initUnix(socket_path);
    try std.posix.connect(
        daemon_socket,
        &address.any,
        address.getOsSockLen(),
    );

    var event = input.input_event{};
    const event_size = @sizeOf(input.input_event);
    while (true) {
        if (std.posix.system.read(
            device.handle,
            @ptrCast(&event),
            event_size,
        ) == event_size) {
            if (event.type == input.EV_KEY) {
                switch (event.code) {
                    input.KEY_H => {
                        move_mouse(daemon_socket, .{ .x = -10, .y = 0 });
                    },
                    input.KEY_J => {
                        move_mouse(daemon_socket, .{ .x = 0, .y = 10 });
                    },
                    input.KEY_K => {
                        move_mouse(daemon_socket, .{ .x = 0, .y = -10 });
                    },
                    input.KEY_L => {
                        move_mouse(daemon_socket, .{ .x = 10, .y = 0 });
                    },
                    input.KEY_M => {
                        mouse_click(daemon_socket, .left);
                    },
                    input.KEY_COMMA => {
                        mouse_click(daemon_socket, .middle);
                    },
                    input.KEY_DOT => {
                        mouse_click(daemon_socket, .right);
                    },
                    input.KEY_C => return,
                    else => {
                        std.debug.print("Key code {d} {d}\n", .{
                            event.code,
                            event.value,
                        });
                    },
                }
                syncronize(daemon_socket);
            }
        }
    }
}
