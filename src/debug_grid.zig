const std = @import("std");
const rl = @import("raylib");

fn drawReferenceGrid(width: i32, height: i32) void {
    const grid_color = rl.Color{.r=150, .g=150, .b=150, .a=100};
    const grid_size: i32 = 50; //50px grid

    // vertical lines
    var x:i32 = 0;
    while(x<width) : (x+=grid_size) {
        rl.drawLine(x, 0, x, height, grid_color);
        // draw coordinate every 100 px
        if(@mod(x, 100) == 0){
            var buf: [16:0]u8 = undefined;
            const text = std.fmt.bufPrintZ(&buf,"{d}", .{x}) catch unreachable;
            rl.drawText(text, x+2, 2, 10, rl.Color.gray);
        }
    }

    // horizontal lines
    var y:i32 = 0;
    while(y<height) : (y+=grid_size) {
        rl.drawLine(0, y, width, y, grid_color);
        // draw coordinate every 100 px
        if(@mod(y, 100) == 0){
            var buf: [16:0]u8 = undefined;
            const text = std.fmt.bufPrintZ(&buf,"{d}", .{y}) catch unreachable;
            rl.drawText(text, 2, y+2, 10, rl.Color.gray);
        }
    }
}

pub const DebugGrid = struct  {
    width: i32,
    height: i32,
    show_grid: bool,

    pub fn init(width:i32, height:i32) DebugGrid{
       return .{.width = width, .height = height, .show_grid = false};
    }

    pub fn draw(self: *DebugGrid, width:i32, height:i32) void{
        self.width = width;
        self.height = height;

        if (rl.isKeyPressed(rl.KeyboardKey.g)) {
            self.show_grid = !self.show_grid;
        }

        if(self.show_grid) {
            drawReferenceGrid(self.width, self.height);
            drawMainZones(self.width, self.height);
        }
    }

    pub fn drawMainZones(width: i32, height:i32) void{
        const margin : i32 = 20;
        _=height;

            const top_bar_height: i32 = 80;        // Title + knobs
            const display_height: i32 = 100;       // Expression display
            const button_grid_height: i32 = 180;   // Number + operator buttons (2 rows)
            const visualizer_height: i32 = 250;      // Visualizer keys
            const control_height: i32 = 80;        // Bottom controls

            var current_y: i32 = margin;

            drawZone(margin, current_y, width - (margin * 2), top_bar_height,
                rl.Color{ .r = 255, .g = 0, .b = 0, .a = 50 }, "TOP BAR");
            current_y += top_bar_height + 10;

            drawZone(margin, current_y, width - (margin * 2), display_height,
                rl.Color{ .r = 0, .g = 0, .b = 255, .a = 50 }, "DISPLAY");
            current_y += display_height + 10;

            drawZone(margin, current_y, width - (margin * 2), button_grid_height,
                rl.Color{ .r = 0, .g = 255, .b = 0, .a = 50 }, "BUTTONS");
            current_y += button_grid_height + 10;

            drawZone(margin, current_y, width - (margin * 2), visualizer_height,
                rl.Color{ .r = 128, .g = 0, .b = 128, .a = 50 }, "Visualizer");
            current_y += visualizer_height + 10;

            drawZone(margin, current_y, width - (margin * 2), control_height,
                rl.Color{ .r = 255, .g = 165, .b = 0, .a = 50 }, "CONTROLS");


    }
    fn drawZone(x: i32, y: i32, w: i32, h: i32, color: rl.Color, label: [:0]const u8) void {
        // Semi-transparent fill
        rl.drawRectangle(x, y, w, h, color);

        // 3D Beveled border effect for elevated look
        const border_width: i32 = 2;

        // Dark shadow on bottom and right (makes it look raised)
        const shadow_color = rl.Color{ .r = 80, .g = 70, .b = 60, .a = 200 };
        rl.drawRectangle(x, y + h - border_width, w, border_width, shadow_color); // Bottom
        rl.drawRectangle(x + w - border_width, y, border_width, h, shadow_color); // Right

        // Light highlight on top and left (simulates light source)
        const highlight_color = rl.Color{ .r = 240, .g = 235, .b = 220, .a = 200 };
        rl.drawRectangle(x, y, w, border_width, highlight_color); // Top
        rl.drawRectangle(x, y, border_width, h, highlight_color); // Left

        // Outer black border for definition
        rl.drawRectangleLines(x, y, w, h, rl.Color{ .r = 60, .g = 55, .b = 50, .a = 255 });

        // Label
        rl.drawText(label, x + 10, y + 10, 16, rl.Color.black);

        // Dimensions
        var buf: [64:0]u8 = undefined;
        const dims = std.fmt.bufPrintZ(&buf, "{d}x{d}", .{w, h}) catch "";
        rl.drawText(dims, x + 10, y + 30, 12, rl.Color.dark_gray);
    }

};
