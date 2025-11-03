const std = @import("std");
const rl = @import("raylib");
const Editor = @import("editor.zig").Editor;
const Window = @import("window.zig").Window;
const customAllocator = @import("allocator.zig").CustomAllocator;
const AudioSystem = @import("audio.zig").AudioSystem;
const Evaluator = @import("evaluator.zig").Evaluator;
const url_state = @import("url_state.zig");
const DebugGrid = @import("debug_grid.zig").DebugGrid;

pub fn main() !void {

    // Window - bigger size to match reference
    var window = Window.init(.{
        .width = 800,
        .height = 450,
        .title = "Zigbeat",
        .target_fps = 60,
    });
    defer window.deinit();

    var debugGrid = DebugGrid.init(window.getWidth(), window.getHeight());

    while (!window.shouldClose()) {
        window.handleResize();
        window.handleFullscreenToggle();


        // ============= DRAW =============
        window.beginDrawing();
        defer window.endDrawing();

        // Beige background like reference
        const bg_color = rl.Color{ .r = 230, .g = 220, .b = 200, .a = 255 };
        window.clearBackground(bg_color);

        debugGrid.draw(window.getWidth(), window.getHeight());
    }
}
