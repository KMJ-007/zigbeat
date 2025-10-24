const rl = @import("raylib");

pub const Window = struct {
    width: i32,
    height: i32,
    title: [:0]const u8,
    
    pub fn init(params: struct {
        width: i32,
        height: i32, 
        title: [:0]const u8,
        target_fps: i32 = 60,
    }) Window {
        rl.initWindow(params.width, params.height, params.title);
        rl.setWindowState(rl.ConfigFlags{ .window_resizable = true });
        rl.setTargetFPS(params.target_fps);
        
        return Window{
            .width = params.width,
            .height = params.height,
            .title = params.title,
        };
    }
    
    pub fn deinit(self: *Window) void {
        _ = self;
        rl.closeWindow();
    }
    
    pub fn shouldClose(self: *const Window) bool {
        _ = self;
        return rl.windowShouldClose();
    }
    
    pub fn handleResize(self: *Window) void {
        if (rl.isWindowResized() and !rl.isWindowFullscreen()) {
            self.width = rl.getScreenWidth();
            self.height = rl.getScreenHeight();
        }
    }
    
    pub fn handleFullscreenToggle(self: *Window) void {
        if (rl.isKeyPressed(rl.KeyboardKey.enter) and 
           (rl.isKeyDown(rl.KeyboardKey.left_alt) or rl.isKeyDown(rl.KeyboardKey.right_alt))) {
            
            const display = rl.getCurrentMonitor();
            
            if (rl.isWindowFullscreen()) {
                rl.setWindowSize(self.width, self.height);
            } else {
                rl.setWindowSize(rl.getMonitorWidth(display), rl.getMonitorHeight(display));
            }
            
            rl.toggleFullscreen();
        }
    }
    
    pub fn beginDrawing(self: *const Window) void {
        _ = self;
        rl.beginDrawing();
    }
    
    pub fn endDrawing(self: *const Window) void {
        _ = self;
        rl.endDrawing();
    }
    
    pub fn clearBackground(self: *const Window, color: rl.Color) void {
        _ = self;
        rl.clearBackground(color);
    }
};