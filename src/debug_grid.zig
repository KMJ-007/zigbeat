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
        }
    }
};
