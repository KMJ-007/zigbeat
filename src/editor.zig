const std = @import("std");
const rl = @import("raylib");

pub const Editor = struct {
    program_buffer: [255:0]u8 = std.mem.zeroes([255:0]u8),
    program_len: u8 = 0,
    cursor_pos: u8 = 0,
    frames_counter: u32 = 0,

    pub fn init() Editor {
        return Editor{};
    }

    pub fn addChar(self: *Editor, char: u8) void {
        if (self.program_len < self.program_buffer.len - 1) {
            // Insert character at cursor position
            if (self.cursor_pos < self.program_len) {
                // Shift characters right to make space
                var i: u8 = self.program_len;
                while (i > self.cursor_pos) {
                    self.program_buffer[i] = self.program_buffer[i - 1];
                    i -= 1;
                }
            }

            self.program_buffer[self.cursor_pos] = char;
            self.program_len += 1;
            self.cursor_pos += 1;
            self.program_buffer[self.program_len] = 0;
        }
    }

    pub fn removeChar(self: *Editor) void {
        if (self.cursor_pos > 0 and self.program_len > 0) {
            self.cursor_pos -= 1;

            // Shift characters left to fill gap
            var i: u8 = self.cursor_pos;
            while (i < self.program_len - 1) {
                self.program_buffer[i] = self.program_buffer[i + 1];
                i += 1;
            }

            self.program_len -= 1;
            self.program_buffer[self.program_len] = 0;
        }
    }

    pub fn moveCursorLeft(self: *Editor) void {
        if (self.cursor_pos > 0) {
            self.cursor_pos -= 1;
        }
    }

    pub fn moveCursorRight(self: *Editor) void {
        if (self.cursor_pos < self.program_len) {
            self.cursor_pos += 1;
        }
    }

    pub fn moveCursorToStart(self: *Editor) void {
        self.cursor_pos = 0;
    }

    pub fn moveCursorToEnd(self: *Editor) void {
        self.cursor_pos = self.program_len;
    }

    pub fn moveCursorUp(self: *Editor, chars_per_line: u8) void {
        if (self.cursor_pos >= chars_per_line) {
            self.cursor_pos -= chars_per_line;
            // Clamp to line end if line is shorter
            if (self.cursor_pos > self.program_len) {
                self.cursor_pos = self.program_len;
            }
        }
    }

    pub fn moveCursorDown(self: *Editor, chars_per_line: u8) void {
        const new_pos = self.cursor_pos + chars_per_line;
        if (new_pos <= self.program_len) {
            self.cursor_pos = @intCast(new_pos);
        } else {
            // Move to end of text if going past
            self.cursor_pos = self.program_len;
        }
    }

    pub fn update(self: *Editor) void {
        self.frames_counter += 1;
    }

    pub fn getCursorVisible(self: *const Editor) bool {
        // Blink every 20 frames (like raylib example)
        return @mod(@divTrunc(self.frames_counter, 20), 2) == 0;
    }

    pub fn getText(self: *const Editor) [:0]const u8 {
        return self.program_buffer[0..self.program_len :0];
    }

    pub fn handleInput(self: *Editor, chars_per_line: u8) void {
        // Handle character input
        var key = rl.getCharPressed();
        while (key > 0) {
            // Filter valid characters (space to ~)
            if (key >= 32 and key <= 125) {
                self.addChar(@intCast(key));
            }
            key = rl.getCharPressed();
        }

        // Handle keys (raylib handles key repeat automatically)
        if (rl.isKeyPressed(rl.KeyboardKey.backspace)) {
            self.removeChar();
        }
        if (rl.isKeyPressed(rl.KeyboardKey.left)) {
            self.moveCursorLeft();
        }
        if (rl.isKeyPressed(rl.KeyboardKey.right)) {
            self.moveCursorRight();
        }
        if (rl.isKeyPressed(rl.KeyboardKey.home)) {
            self.moveCursorToStart();
        }
        if (rl.isKeyPressed(rl.KeyboardKey.end)) {
            self.moveCursorToEnd();
        }
        if (rl.isKeyPressed(rl.KeyboardKey.up)) {
            self.moveCursorUp(chars_per_line);
        }
        if (rl.isKeyPressed(rl.KeyboardKey.down)) {
            self.moveCursorDown(chars_per_line);
        }
        if (rl.isKeyPressed(rl.KeyboardKey.escape)) {
            // Clear all text
            self.program_len = 0;
            self.cursor_pos = 0;
            self.program_buffer[0] = 0;
        }
    }
};