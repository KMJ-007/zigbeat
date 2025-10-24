const std = @import("std");
const rl = @import("raylib");
const Editor = @import("editor.zig").Editor;
const ui = @import("ui.zig");
const Window = @import("window.zig").Window;
const customAllocator = @import("allocator.zig").CustomAllocator;

pub fn main() !void {
    var gpa = customAllocator{};
    const allocator = gpa.allocator();
    // Initialize editor
    var editor = try Editor.init(allocator);
    defer editor.deinit();

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
