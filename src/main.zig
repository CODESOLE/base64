const std = @import("std");

fn encode(content: []u8, letters: *const [64:0]u8) !void {
    var chunk_idx: usize = 0;
    const stdout = std.io.getStdOut().writer();
    var b = std.io.bufferedWriter(stdout);
    var bw = b.writer();
    while (chunk_idx < content.len) : (chunk_idx += 3) {
        const data = if (chunk_idx + 3 >= content.len) content[chunk_idx..] else content[chunk_idx .. chunk_idx + 3];
        switch (data.len) {
            1 => {
                const e1 = letters[0b0011_1111 & (data[0] >> 2)];
                const e2 = letters[(0x30 & (data[0] << 4)) | 0x00];
                try bw.print("{c}{c}==", .{ e1, e2 });
            },
            2 => {
                const e1 = letters[0b0011_1111 & (data[0] >> 2)];
                const e2 = letters[(0x30 & (data[0] << 4)) | (0x0F & (data[1] >> 4))];
                const e3 = letters[(0b0011_1100 & (data[1] << 2)) | 0b0000_0000];
                try bw.print("{c}{c}{c}=", .{ e1, e2, e3 });
            },
            3 => {
                const e1 = letters[0b0011_1111 & (data[0] >> 2)];
                const e2 = letters[(0x30 & (data[0] << 4)) | (0x0F & (data[1] >> 4))];
                const e3 = letters[(0b0011_1100 & (data[1] << 2)) | (0b0000_0011 & (data[2] >> 6))];
                const e4 = letters[0b0011_1111 & data[2]];
                try bw.print("{c}{c}{c}{c}", .{ e1, e2, e3, e4 });
            },
            else => unreachable,
        }
    }
    try b.flush();
}

fn decode(content: []u8, letters: *const [64:0]u8) !void {
    std.debug.assert(content.len % 4 == 0);
    var chunk_idx: usize = 0;
    const stdout = std.io.getStdOut().writer();
    var b = std.io.bufferedWriter(stdout);
    var bw = b.writer();
    const is_urlsafe = if (letters[63] == '/') false else true;
    while (chunk_idx < content.len) : (chunk_idx += 4) {
        const data = content[chunk_idx .. chunk_idx + 4];
        if (is_urlsafe) {
            for (data) |c| {
                if (c == '/' or c == '+') @panic("Couldn't complete decoding! Conflicting decoding standart. Expected urlsafe encoding but found standard encoding.\nHint: use `base64 -d <file>`");
            }
        } else {
            for (data) |c| {
                if (c == '-' or c == '_') @panic("Couldn't complete decoding! Conflicting decoding standard. Expected standard encoding but found urlsafe encoding.\nHint: use `urlsafe=1 base64 -d <file>`");
            }
        }
        const l1: u8 = for (letters, 0..) |l, idx| {
            if (l == data[0]) break @truncate(idx);
        } else 0x00;
        const l2: u8 = for (letters, 0..) |l, idx| {
            if (l == data[1]) break @truncate(idx);
        } else 0x00;
        const l3: u8 = for (letters, 0..) |l, idx| {
            if (l == data[2]) break @truncate(idx);
        } else 0x00;
        const l4: u8 = for (letters, 0..) |l, idx| {
            if (l == data[3]) break @truncate(idx);
        } else 0x00;

        if (data[3] != '=' and data[2] == '=')
            @panic("Invalid sequence!");

        if (data[3] == '=' and data[2] == '=') {
            const e1: u8 = ((l1 << 2) & 0b1111_1100) | ((l2 >> 4) & 0b0000_0011);
            try bw.print("{c}", .{e1});
        } else if (data[3] == '=' and data[2] != '=') {
            const e1: u8 = ((l1 << 2) & 0b1111_1100) | ((l2 >> 4) & 0b0000_0011);
            const e2: u8 = ((l2 << 4) & 0b1111_0000) | ((l3 >> 2) & 0b0000_1111);
            try bw.print("{c}{c}", .{ e1, e2 });
        } else {
            const e1: u8 = ((l1 << 2) & 0b1111_1100) | ((l2 >> 4) & 0b0000_0011);
            const e2: u8 = ((l2 << 4) & 0b1111_0000) | ((l3 >> 2) & 0b0000_1111);
            const e3: u8 = ((l3 << 6) & 0b1100_0000) | (l4 & 0b0011_1111);
            try bw.print("{c}{c}{c}", .{ e1, e2, e3 });
        }
    }
    try b.flush();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.detectLeaks()) @panic("Memory leak!!!\n");
    const allocator = gpa.allocator();
    var env = try std.process.getEnvMap(allocator);
    defer env.deinit();
    const is_urlsafe = if (env.get("URLSAFE") != null or env.get("urlsafe") != null) true else false;
    const letters = blk: {
        if (is_urlsafe) {
            std.debug.print("URLSAFE defined via env var!\n", .{});
            break :blk "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
        } else {
            std.debug.print("URLSAFE NOT defined via env var!\n", .{});
            break :blk "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        }
    };
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.next(); // executable itself
    const mode = args.next() orelse @panic("Usage: base64 [-e | -d] <file>");
    const file_str = args.next() orelse @panic("Usage: base64 [-e | -d] <file>");
    const file = try std.fs.cwd().openFile(file_str, .{});
    defer file.close();
    const metadata = try file.metadata();
    std.debug.assert(metadata.kind() == .file);
    const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(content);
    if (std.mem.eql(u8, mode, "-e")) {
        try encode(content, letters);
    } else if (std.mem.eql(u8, mode, "-d")) {
        try decode(content, letters);
    } else {
        @panic("Usage: base64 [-e | -d] <file>");
    }
}
