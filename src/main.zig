const rl = @import("raylib");

pub fn main() !void {
    rl.initWindow(800, 450, "ZigBeat");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.orange);
        rl.drawText("Hello, This is working!", 20, 20, 20, rl.Color.black);
    }
}
