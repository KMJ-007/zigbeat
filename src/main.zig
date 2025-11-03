const rl = @import("raylib");
const Window = @import("window.zig").Window;
const DebugGrid = @import("debug_grid.zig").DebugGrid;
const background = @import("background.zig");

pub fn main() !void {
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

        window.beginDrawing();
        defer window.endDrawing();

        window.clearBackground(rl.Color.black);
        background.drawMetallicCRT(window.getWidth(), window.getHeight());

        debugGrid.draw(window.getWidth(), window.getHeight());
    }
}
