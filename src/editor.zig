const std = @import("std");
const rl = @import("raylib");

pub const Editor = struct {
    allocator: std.mem.Allocator,
    program: std.ArrayList(u8),
    cursor_pos: usize = 0,
    frames_counter: u32 = 0,

    key_repeat_counter: u32 = 0,
    last_repeated_key: rl.KeyboardKey = rl.KeyboardKey.null,

    // Error handling
    error_message: ?[]const u8 = null,
    error_display_frames: u32 = 0,

    pub fn init(allocator: std.mem.Allocator) !Editor {
        return Editor{
            .allocator = allocator,
            .program = std.ArrayList(u8).empty,
        };
    }

    pub fn deinit(self: *Editor) void {
        self.program.deinit(self.allocator);
    }

    pub fn addChar(self: *Editor, char: u8) void {
        self.program.insert(self.allocator, self.cursor_pos, char) catch |err| {
            switch (err) {
                error.OutOfMemory => self.setError("Out of memory - cannot add more text"),
            }
            return;
        };
        self.cursor_pos += 1;
        // Clear any previous errors on successful operation
        if (self.hasError()) {
            self.clearError();
        }
    }

    pub fn removeChar(self: *Editor) void {
        if (self.cursor_pos > 0 and self.program.items.len > 0) {
            self.cursor_pos -= 1;
            _ = self.program.orderedRemove(self.cursor_pos);
        }
    }

    pub fn moveCursorLeft(self: *Editor) void {
        if (self.cursor_pos > 0) {
            self.cursor_pos -= 1;
        }
    }

    pub fn moveCursorRight(self: *Editor) void {
        if (self.cursor_pos < self.program.items.len) {
            self.cursor_pos += 1;
        }
    }

    pub fn moveCursorToStart(self: *Editor) void {
        self.cursor_pos = 0;
    }

    pub fn moveCursorToEnd(self: *Editor) void {
        self.cursor_pos = self.program.items.len;
    }

    pub fn moveCursorUp(self: *Editor, chars_per_line: usize) void {
        if (self.cursor_pos >= chars_per_line) {
            self.cursor_pos -= chars_per_line;
            // Clamp to line end if line is shorter
            if (self.cursor_pos > self.program.items.len) {
                self.cursor_pos = self.program.items.len;
            }
        }
    }

    pub fn moveCursorDown(self: *Editor, chars_per_line: usize) void {
        const new_pos = self.cursor_pos + chars_per_line;
        if (new_pos <= self.program.items.len) {
            self.cursor_pos = new_pos;
        } else {
            // Move to end of text if going past
            self.cursor_pos = self.program.items.len;
        }
    }

    pub fn update(self: *Editor) void {
        self.frames_counter += 1;

        // Update error display timer
        if (self.error_message != null) {
            self.error_display_frames += 1;
            // Clear error after 3 seconds (180 frames at 60fps)
            if (self.error_display_frames >= 180) {
                self.clearError();
            }
        }
    }

    pub fn setError(self: *Editor, message: []const u8) void {
        self.error_message = message;
        self.error_display_frames = 0;
    }

    pub fn clearError(self: *Editor) void {
        self.error_message = null;
        self.error_display_frames = 0;
    }

    pub fn hasError(self: *const Editor) bool {
        return self.error_message != null;
    }

    pub fn getErrorMessage(self: *const Editor) ?[]const u8 {
        return self.error_message;
    }

    pub fn getCursorVisible(self: *const Editor) bool {
        // Blink every 20 frames (like raylib example)
        return @mod(@divTrunc(self.frames_counter, 20), 2) == 0;
    }

    pub fn getText(self: *const Editor) []const u8 {
        return self.program.items;
    }

    fn handleKeyRepeat(self: *Editor, key: rl.KeyboardKey, action: fn (*Editor) void) void {
        const initial_delay = 30; // ~0.5 seconds at 60fps
        const repeat_rate = 3; // Every 3 frames after initial delay

        if (rl.isKeyPressed(key)) {
            // First press - execute immediately
            action(self);
            self.last_repeated_key = key;
            self.key_repeat_counter = 0;
        } else if (rl.isKeyDown(key) and self.last_repeated_key == key) {
            // Key held - handle repeat
            self.key_repeat_counter += 1;
            if (self.key_repeat_counter > initial_delay) {
                if (@mod(self.key_repeat_counter - initial_delay, repeat_rate) == 0) {
                    action(self);
                }
            }
        } else if (self.last_repeated_key == key) {
            // Key released - reset
            self.last_repeated_key = rl.KeyboardKey.null;
            self.key_repeat_counter = 0;
        }
    }

    fn handleKeyRepeatWithParam(self: *Editor, key: rl.KeyboardKey, action: fn (*Editor, usize) void, param: usize) void {
        const initial_delay = 30;
        const repeat_rate = 3;

        if (rl.isKeyPressed(key)) {
            action(self, param);
            self.last_repeated_key = key;
            self.key_repeat_counter = 0;
        } else if (rl.isKeyDown(key) and self.last_repeated_key == key) {
            self.key_repeat_counter += 1;
            if (self.key_repeat_counter > initial_delay) {
                if (@mod(self.key_repeat_counter - initial_delay, repeat_rate) == 0) {
                    action(self, param);
                }
            }
        } else if (self.last_repeated_key == key) {
            self.last_repeated_key = rl.KeyboardKey.null;
            self.key_repeat_counter = 0;
        }
    }

    pub fn handleInput(self: *Editor, chars_per_line: usize) void {
        // Handle character input (GetCharPressed handles repeat automatically)
        var key = rl.getCharPressed();
        while (key > 0) {
            // Filter valid characters (space to ~)
            if (key >= 32 and key <= 125) {
                self.addChar(@intCast(key));
            }
            key = rl.getCharPressed();
        }

        // Handle keys with repeat functionality
        self.handleKeyRepeat(rl.KeyboardKey.backspace, Editor.removeChar);
        self.handleKeyRepeat(rl.KeyboardKey.left, Editor.moveCursorLeft);
        self.handleKeyRepeat(rl.KeyboardKey.right, Editor.moveCursorRight);
        self.handleKeyRepeatWithParam(rl.KeyboardKey.up, Editor.moveCursorUp, chars_per_line);
        self.handleKeyRepeatWithParam(rl.KeyboardKey.down, Editor.moveCursorDown, chars_per_line);

        // Single press keys (no repeat needed)
        if (rl.isKeyPressed(rl.KeyboardKey.home)) {
            self.moveCursorToStart();
        }
        if (rl.isKeyPressed(rl.KeyboardKey.end)) {
            self.moveCursorToEnd();
        }
        if (rl.isKeyPressed(rl.KeyboardKey.escape)) {
            // If there's an error, clear it first. If no error, clear all text
            if (self.hasError()) {
                self.clearError();
            } else {
                // Clear all text
                self.cursor_pos = 0;
                self.program.clearAndFree(self.allocator);
            }
        }
    }
};
