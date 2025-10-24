const rl = @import("raylib");
const Editor = @import("editor.zig").Editor;

pub const TextArea = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    font_size: i32,

    pub fn drawText(self: TextArea, text: [:0]const u8) void {
        const line_height = self.font_size + 2;
        const chars_per_line = @divTrunc(self.width, @divTrunc(self.font_size * 6, 10));

        var current_line: i32 = 0;
        var current_x: i32 = self.x;
        var current_y: i32 = self.y;
        var chars_in_line: i32 = 0;

        for (text) |char| {
            // Check if we need to wrap to next line
            if (chars_in_line >= chars_per_line or current_y + line_height > self.y + self.height) {
                current_line += 1;
                current_x = self.x;
                current_y = self.y + (current_line * line_height);
                chars_in_line = 0;

                // Stop if we exceed the text area height
                if (current_y + line_height > self.y + self.height) {
                    break;
                }
            }

            // Draw single character
            const char_str = [2:0]u8{ char, 0 };
            rl.drawText(&char_str, current_x, current_y, self.font_size, rl.Color.white);

            current_x += @divTrunc(self.font_size * 6, 10);
            chars_in_line += 1;
        }
    }
    
    pub fn drawEditor(self: TextArea, editor: *const Editor) void {
        const text = editor.getText();
        const line_height = self.font_size + 2;
        const char_width = @divTrunc(self.font_size * 6, 10);
        const chars_per_line = @divTrunc(self.width, char_width);

        var current_line: i32 = 0;
        var current_x: i32 = self.x;
        var current_y: i32 = self.y;
        var chars_in_line: i32 = 0;
        var cursor_x: i32 = self.x;
        var cursor_y: i32 = self.y;

        // Draw text and track cursor position
        for (text, 0..) |char, i| {
            // Check if we need to wrap to next line
            if (chars_in_line >= chars_per_line) {
                current_line += 1;
                current_x = self.x;
                current_y = self.y + (current_line * line_height);
                chars_in_line = 0;

                // Stop if we exceed the text area height
                if (current_y + line_height > self.y + self.height) {
                    break;
                }
            }

            // Track cursor position
            if (i == editor.cursor_pos) {
                cursor_x = current_x;
                cursor_y = current_y;
            }

            // Draw single character
            const char_str = [2:0]u8{ char, 0 };
            rl.drawText(&char_str, current_x, current_y, self.font_size, rl.Color.white);

            current_x += char_width;
            chars_in_line += 1;
        }

        // Set cursor position at end if cursor is at end of text
        if (editor.cursor_pos >= text.len) {
            cursor_x = current_x;
            cursor_y = current_y;
        }

        // Draw cursor
        if (editor.getCursorVisible()) {
            rl.drawRectangle(cursor_x, cursor_y, 2, self.font_size, rl.Color.white);
        }
    }

    pub fn drawBorder(self: TextArea) void {
        rl.drawRectangleLines(self.x - 2, self.y - 2, self.width + 4, self.height + 4, rl.Color.gray);
    }
    
    pub fn getCharsPerLine(self: TextArea) u8 {
        const char_width = @divTrunc(self.font_size * 6, 10);
        return @intCast(@divTrunc(self.width, char_width));
    }
};


pub fn drawTitle(params: struct {
    text: [:0]const u8,
    x: i32,
    y: i32,
    font_size: i32,
    color: rl.Color = rl.Color.white,
}) void {
    rl.drawText(params.text, params.x, params.y, params.font_size, params.color);
}

pub fn createTextArea(params: struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    font_size: i32 = 16,
}) TextArea {
    return TextArea{
        .x = params.x,
        .y = params.y,
        .width = params.width,
        .height = params.height,
        .font_size = params.font_size,
    };
}
