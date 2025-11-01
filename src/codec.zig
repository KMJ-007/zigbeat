const std = @import("std");

/// Decode a hex-encoded bb parameter into UTF-8 text
pub fn decodeBb(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    if (hex.len == 0) return error.EmptyInput;

    if (hex.len % 2 != 0) return error.InvalidHexLength;

    const result = try allocator.alloc(u8, hex.len / 2);
    errdefer allocator.free(result);

    _ = try std.fmt.hexToBytes(result, hex);

    // Validate UTF-8
    if (!std.unicode.utf8ValidateSlice(result)) {
        return error.InvalidUtf8;
    }

    return result;
}

/// Encode UTF-8 text into hex format for bb parameter
pub fn encodeBb(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    if (text.len == 0) return error.EmptyInput;

    if (!std.unicode.utf8ValidateSlice(text)) {
        return error.InvalidUtf8;
    }

    const result = try allocator.alloc(u8, text.len * 2);
    errdefer allocator.free(result);

    // Convert bytes to hex manually
    const hex_chars = "0123456789abcdef";
    for (text, 0..) |byte, i| {
        result[i * 2] = hex_chars[byte >> 4];
        result[i * 2 + 1] = hex_chars[byte & 0x0F];
    }

    return result;
}
