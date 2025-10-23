const rl = @import("raylib");

pub fn main() !void {
    defer rl.closeWindow();

    var screenWidth: i32 = 800;
    var screenHeight: i32 = 450;

    rl.initWindow(screenWidth, screenHeight, "Zigbeat");
    rl.setWindowState(rl.ConfigFlags{ .window_resizable = true });
    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        // Update screen dimensions when window is resized (but not in fullscreen)
        if (rl.isWindowResized() and !rl.isWindowFullscreen()) {
            screenWidth = rl.getScreenWidth();
            screenHeight = rl.getScreenHeight();
        }

        // check for alt + enter
        if (rl.isKeyPressed(rl.KeyboardKey.enter) and (rl.isKeyDown(rl.KeyboardKey.left_alt) or rl.isKeyDown(rl.KeyboardKey.right_alt))) {
            // see what display we are on right now
            const display = rl.getCurrentMonitor();

            if (rl.isWindowFullscreen()) {
                // if we are full screen, then go back to the windowed size
                rl.setWindowSize(screenWidth, screenHeight);
            } else {
                // if we are not full screen, set the window size to match the monitor we are on
                rl.setWindowSize(rl.getMonitorWidth(display), rl.getMonitorHeight(display));
            }

            // toggle the state
            rl.toggleFullscreen();
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.orange);
        rl.drawText("Hello, This is working!", 20, 20, 20, rl.Color.black);
    }
}
