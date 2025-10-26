const std = @import("std");
const rl = @import("raylib");
const Editor = @import("editor.zig").Editor;
const ui = @import("ui.zig");
const Window = @import("window.zig").Window;
const customAllocator = @import("allocator.zig").CustomAllocator;
const AudioSystem = @import("audio.zig").AudioSystem;
const Evaluator = @import("evaluator.zig").Evaluator;

pub fn main() !void {
    var gpa = customAllocator{};
    const allocator = gpa.allocator();
    // Initialize editor
    var editor = try Editor.init(allocator);
    defer editor.deinit();

    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "t");

    var evaluator = try Evaluator.init(allocator, .{
        .expression =  expr,
        .beat_type = .bytebeat,
        .sample_rate = .rate_8000
    });
    defer evaluator.deinit();

    // Intialize Audio
    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    var audio = try AudioSystem.init(&evaluator);
    defer audio.deinit();

    audio.activate();
    audio.play();

    // Initialize window
    var window = Window.init(.{
        .width = 800,
        .height = 450,
        .title = "Zigbeat",
        .target_fps = 60,
    });
    defer window.deinit();

    const coding_font = ui.loadProgrammingFont("assets/JetBrainsMono-Regular.ttf", 20);

    while (!window.shouldClose()) {
        // ============= Window Management =============
        window.handleResize();
        window.handleFullscreenToggle();

        editor.update();

        // Create text area to get dimensions for input handling
        const text_area = ui.createTextArea(.{
            .x = 50,
            .y = 60,
            .width = window.width - 100,
            .height = window.height - 120,
            .font_size = 20,
            .font = coding_font,
        });

        editor.handleInput(text_area.getCharsPerLine());

        // ============= Draw =============
        window.beginDrawing();
        defer window.endDrawing();

        window.clearBackground(rl.Color.black);

        ui.drawTitle(.{
            .text = "Zigbeat",
            .x = 20,
            .y = 20,
            .font_size = 20,
        });

        text_area.drawEditor(&editor);

        // Debug: Show audio time
        const audio_time = audio.getTime();
        const sample_rate = audio.getSampleRate();
        const total_ms = (@as(u64, audio_time) * 1000) / @as(u64, sample_rate);
        const seconds = total_ms / 1000;
        const milliseconds = total_ms % 1000;
        var debug_buf: [64:0]u8 = undefined;
        const debug_text = std.fmt.bufPrintZ(&debug_buf, "Audio Time: {d}s {d}ms", .{seconds, milliseconds}) catch unreachable;
        rl.drawText(debug_text, 20, window.height - 70, 14, rl.Color.green);

        // Draw error message at the bottom if there is one
        if (editor.getErrorMessage()) |error_msg| {
            ui.drawErrorMessage(.{
                .message = error_msg,
                .x = 20,
                .y = window.height - 40,
                .font_size = 16,
            });
        }
    }
}
