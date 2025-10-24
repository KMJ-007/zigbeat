const std = @import("std");
const rl = @import("raylib");

pub const Editor = struct {
    program_buffer: [255:0]u8 = std.mem.zeroes([255:0]u8),
    program_len: u8 = 0,
    cursor_pos: u8 = 0,
    cursor_blink_timer: f32 = 0.0,
    cursor_visible: bool = true,
    
    // Key repeat state
    last_key: i32 = 0,
    key_repeat_timer: f32 = 0.0,
    key_repeat_delay: f32 = 0.5,  // Initial delay before repeat
    key_repeat_rate: f32 = 0.05,  // Repeat interval
    
    pub fn init() Editor {
        return Editor{};
    }
    
    pub fn addChar(self: *Editor, char: u8) void {
        if (self.program_len < self.program_buffer.len - 1) {
            self.program_buffer[self.program_len] = char;
            self.program_len += 1;
            self.cursor_pos = self.program_len;
            self.program_buffer[self.program_len] = 0;
            self.resetCursorBlink();
        }
    }
    
    pub fn removeChar(self: *Editor) void {
        if (self.program_len > 0) {
            self.program_len -= 1;
            self.cursor_pos = self.program_len;
            self.program_buffer[self.program_len] = 0;
            self.resetCursorBlink();
        }
    }
    
    pub fn update(self: *Editor) void {
        const dt = rl.getFrameTime();
        
        // Update cursor blink
        self.cursor_blink_timer += dt;
        if (self.cursor_blink_timer >= 0.5) {
            self.cursor_visible = !self.cursor_visible;
            self.cursor_blink_timer = 0.0;
        }
    }
    
    pub fn resetCursorBlink(self: *Editor) void {
        self.cursor_blink_timer = 0.0;
        self.cursor_visible = true;
    }
    
    pub fn getCursorVisible(self: *const Editor) bool {
        return self.cursor_visible;
    }
    
    pub fn getText(self: *const Editor) [:0]const u8 {
        return self.program_buffer[0..self.program_len :0];
    }
    
    pub fn handleInput(self: *Editor) void {
        const dt = rl.getFrameTime();
        
        // Handle character input (no repeat needed for regular chars)
        var key = rl.getCharPressed();
        while (key > 0) {
            // Filter valid characters (space to ~)
            if (key >= 32 and key <= 125) {
                self.addChar(@intCast(key));
            }
            key = rl.getCharPressed();
        }
        
        // Handle backspace with key repeat
        if (rl.isKeyDown(rl.KeyboardKey.backspace)) {
            if (rl.isKeyPressed(rl.KeyboardKey.backspace)) {
                // First press
                self.removeChar();
                self.last_key = @intFromEnum(rl.KeyboardKey.backspace);
                self.key_repeat_timer = 0.0;
            } else if (self.last_key == @intFromEnum(rl.KeyboardKey.backspace)) {
                // Held key - handle repeat
                self.key_repeat_timer += dt;
                if (self.key_repeat_timer >= self.key_repeat_delay) {
                    // Start repeating
                    if (@mod(self.key_repeat_timer - self.key_repeat_delay, self.key_repeat_rate) < dt) {
                        self.removeChar();
                    }
                }
            }
        } else {
            // Reset key repeat if backspace released
            if (self.last_key == @intFromEnum(rl.KeyboardKey.backspace)) {
                self.last_key = 0;
            }
        }
        
        // Handle escape key
        if (rl.isKeyPressed(rl.KeyboardKey.escape)) {
            // Clear all text
            self.program_len = 0;
            self.cursor_pos = 0;
            self.program_buffer[0] = 0;
            self.resetCursorBlink();
        }
    }
};