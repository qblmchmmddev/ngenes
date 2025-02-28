const std = @import("std");
const sg = @import("sokol").gfx;
const Palette = [4]u32{
    0xFF000000, // Black
    0xFF555555, // Dark gray
    0xFFAAAAAA, // Light gray
    0xFFFFFFFF, // White
};

fn mapColor(index: u8) u32 {
    return Palette[index];
}

fn decodeTile(chr: []const u8, index: usize, pixels: *[8 * 8 * 4]u8) void {
    const offset = index * 16;
    var p: usize = 0;
    for (0..8) |y| {
        const plane0 = chr[offset + y];
        const plane1 = chr[offset + y + 8];
        for (0..8) |x| {
            const bit0 = (plane0 >> (@as(u3, @intCast(7 - x)))) & 1;
            const bit1 = (plane1 >> (@as(u3, @intCast(7 - x)))) & 1;
            const colorIndex = (bit1 << 1) | bit0;
            const color = mapColor(@as(u8, @intCast(colorIndex)));

            pixels[p + 0] = @as(u8, @intCast((color >> 16) & 0xFF)); // R
            pixels[p + 1] = @as(u8, @intCast((color >> 8) & 0xFF)); // G
            pixels[p + 2] = @as(u8, @intCast((color >> 0) & 0xFF)); // B
            pixels[p + 3] = 0xFF; // A
            p += 4;
        }
    }
}

fn parseChrToRgba8(allocator: std.mem.Allocator, chr: []const u8) ![]u8 {
    const numTiles = chr.len / 16;
    const pixelsPerTile = 8 * 8 * 4;
    const atlasWidth = 16 * 8; // 16 tiles per row
    const atlasHeight = (numTiles / 16) * 8;

    const buffer = try allocator.alloc(u8, atlasWidth * atlasHeight * 4);
    @memset(buffer, 0);

    for (0..numTiles) |tileIndex| {
        var tilePixels: [pixelsPerTile]u8 = undefined;
        decodeTile(chr, tileIndex, &tilePixels);

        const row = tileIndex / 16;
        const col = tileIndex % 16;

        const startX = col * 8;
        const startY = row * 8;

        for (0..8) |y| {
            const destOffset = ((startY + y) * atlasWidth + startX) * 4;
            const srcOffset = y * 8 * 4;
            @memcpy(buffer[destOffset..][0 .. 8 * 4], tilePixels[srcOffset..][0 .. 8 * 4]);
        }
    }

    return buffer;
}

pub fn createImage(chr: []const u8, image_desc: *sg.ImageDesc, allocator: std.mem.Allocator) !sg.Image {
    const pixels = try parseChrToRgba8(allocator, chr);
    defer allocator.free(pixels);

    image_desc.width = 128;
    image_desc.height = @intCast((chr.len / (16 * 16)) * 8);
    image_desc.pixel_format = .RGBA8;
    image_desc.data.subimage[0][0] = .{ .ptr = pixels.ptr, .size = pixels.len };
    return sg.makeImage(image_desc.*);
}
//https://www.nesdev.org/wiki/INES
pub const Cartridge = struct {
    header: [16]u8,
    prg_rom: []u8,
    chr_rom: []u8,
    mapper: u8,

    pub fn load(allocator: std.mem.Allocator, filename: []const u8) !Cartridge {
        const file = if (std.fs.path.isAbsolute(filename))
            try std.fs.openFileAbsolute(filename, .{})
        else
            try std.fs.cwd().openFile(filename, .{});
        defer file.close();

        var buffer = try file.readToEndAlloc(allocator, 1024 * 512); // Max 512 KB ROM
        defer allocator.free(buffer);

        if (buffer.len < 16 or !std.mem.eql(u8, buffer[0..4], "NES\x1a")) {
            return error.InvalidNESFile;
        }

        const prg_size = @as(usize, buffer[4]) * 16 * 1024;
        const chr_size = @as(usize, buffer[5]) * 8 * 1024;
        const mapper = (buffer[6] >> 4) | (buffer[7] & 0xF0);

        const prg_rom = buffer[16 .. 16 + prg_size];
        const chr_rom = buffer[16 + prg_size .. 16 + prg_size + chr_size];

        return Cartridge{
            .header = buffer[0..16].*,
            .prg_rom = try allocator.dupe(u8, prg_rom),
            .chr_rom = try allocator.dupe(u8, chr_rom),
            .mapper = mapper,
        };
    }

    pub fn deinit(self: *Cartridge, allocator: std.mem.Allocator) void {
        allocator.free(self.prg_rom);
        allocator.free(self.chr_rom);
    }
};

fn printHexBytes(bytes: []u8) void {
    for (bytes, 0..) |b, i| {
        if (i % 16 == 0) std.debug.print("\n", .{}); // New line every 16 bytes
        std.debug.print("0x{X:0>2}, ", .{b}); // Print in hex with "0x" prefix
    }
    std.debug.print("\n", .{}); // Final newline
}
