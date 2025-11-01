const std = @import("std");
const codec = @import("codec.zig");
const builtin = @import("builtin");

// Only define Emscripten interface for web target
const emscripten_available = builtin.target.os.tag == .emscripten;

// Emscripten JavaScript interface (only for web builds)
extern "c" fn emscripten_run_script_string(script: [*:0]const u8) [*:0]const u8;

/// Get bb parameter from URL (web only)
pub fn getBbFromUrl(allocator: std.mem.Allocator) !?[]u8 {
    if (!emscripten_available) {
        // Native builds don't support URL state
        return null;
    }

    const js_result = emscripten_run_script_string("window.zigbeat.getBbFromUrl() || ''");
    const hex_str_temp = std.mem.span(js_result);

    if (hex_str_temp.len == 0) return null;

    // Copy the hex string immediately (emscripten result is temporary)
    const hex_str = try allocator.dupe(u8, hex_str_temp);
    defer allocator.free(hex_str);

    std.debug.print("URL bb parameter (hex): {s}\n", .{hex_str});

    // Decode the hex string to get the expression text
    const decoded = codec.decodeBb(allocator, hex_str) catch |err| {
        std.debug.print("Failed to decode bb parameter: {} (hex: {s})\n", .{ err, hex_str });
        return null;
    };

    return decoded;
}

/// Update URL with current expression (web only)
pub fn updateUrlWithExpression(allocator: std.mem.Allocator, text: []const u8) void {
    if (!emscripten_available) {
        // Native builds don't support URL state
        return;
    }

    if (text.len == 0) {
        // Clear URL if expression is empty
        _ = emscripten_run_script_string("window.zigbeat.updateUrlWithBb('')");
        return;
    }

    // Encode the expression to hex
    const encoded = codec.encodeBb(allocator, text) catch |err| {
        std.debug.print("Failed to encode expression: {}\n", .{err});
        return;
    };
    defer allocator.free(encoded);

    // Create null-terminated string for JavaScript
    var js_call_buf: [4096]u8 = undefined;
    const js_call = std.fmt.bufPrintZ(
        &js_call_buf,
        "window.zigbeat.updateUrlWithBb('{s}')",
        .{encoded},
    ) catch {
        std.debug.print("Expression too long for URL encoding\n", .{});
        return;
    };

    _ = emscripten_run_script_string(js_call);
}
