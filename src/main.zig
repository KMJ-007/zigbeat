const std = @import("std");
const rl = @import("raylib");
const Editor = @import("editor.zig").Editor;
const ui = @import("ui.zig");
const Window = @import("window.zig").Window;

pub fn main() !void {
    // Initialize allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // Initialize editor
    var editor = Editor.init();

    // Initialize window
    var window = Window.init(.{
        .width = 800,
        .height = 450,
        .title = "Zigbeat",
        .target_fps = 60,
    });
    defer window.deinit();

    while (!window.shouldClose()) {
        // ============= Window Management =============
        window.handleResize();
        window.handleFullscreenToggle();

        // ============= Update =============
        editor.update();
        editor.handleInput();

        // ============= Draw =============
        window.beginDrawing();
        defer window.endDrawing();

        window.clearBackground(rl.Color.black);

        ui.drawTitle(.{
            .text = "Zigbeat - Bytebeat Editor",
            .x = 20,
            .y = 20,
            .font_size = 20,
        });

        // Create and draw text area
        const text_area = ui.createTextArea(.{
            .x = 50,
            .y = 60,
            .width = window.width - 100,
            .height = window.height - 120,
        });

        text_area.drawEditor(&editor);
    }
}
