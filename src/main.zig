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
    try editor.setText("t*(42&t>>10)");
    editor.markClean();

    const expr = std.ArrayList(u8).empty;

    var evaluator = try Evaluator.init(allocator, .{ .expression = expr, .beat_type = .bytebeat, .sample_rate = .rate_8000 });
    defer evaluator.deinit();
    const initial_text = editor.getText();
    if (initial_text.len > 0) {
        try evaluator.setExpression(initial_text);
    }

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
        if (editor.isDirty()) {
            const text = editor.getText();
            const expression_valid = editor.handleExpressionUpdate(&evaluator, text);
            audio.handleExpressionState(expression_valid);
            editor.markClean();
        }

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
        const audio_samples = audio.getTime();

        var debug_buf: [96:0]u8 = undefined;
        const debug_text = std.fmt.bufPrintZ(
            &debug_buf,
            "Audio Samples: {d}",
            .{audio_samples},
        ) catch unreachable;
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
