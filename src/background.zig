const rl = @import("raylib");

pub fn drawMetallicCRT(width: i32, height: i32) void {
    const top_color = rl.Color{ .r = 42, .g = 42, .b = 42, .a = 255 };
    const bottom_color = rl.Color{ .r = 26, .g = 26, .b = 26, .a = 255 };

    rl.drawRectangleGradientV(0, 0, width, height, top_color, bottom_color);

    const vignette_size: i32 = 80;
    const vignette_color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 76 };
    const transparent = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 0 };

    rl.drawRectangleGradientV(0, 0, width, vignette_size, vignette_color, transparent);
    rl.drawRectangleGradientV(0, height - vignette_size, width, vignette_size, transparent, vignette_color);
    rl.drawRectangleGradientH(0, 0, vignette_size, height, vignette_color, transparent);
    rl.drawRectangleGradientH(width - vignette_size, 0, vignette_size, height, transparent, vignette_color);

    const margin: i32 = 0;
    const border_thickness: i32 = 2;

    rl.drawRectangle(margin, margin, width - (margin * 2), border_thickness, rl.Color.white);
    rl.drawRectangle(margin, margin, border_thickness, height - (margin * 2), rl.Color.white);
    rl.drawRectangle(width - margin - border_thickness, margin, border_thickness, height - (margin * 2), rl.Color.white);

    drawInnerBackground(width, height, margin, border_thickness);
}

fn drawInnerBackground(width: i32, height: i32, margin: i32, border: i32) void {
    const inner_x = margin + border;
    const inner_y = margin + border;
    const inner_width = width - (margin * 2) - (border * 2);
    const inner_height = height - (margin * 2) - border;

    const beige_top = rl.Color{ .r = 215, .g = 205, .b = 185, .a = 255 };
    const beige_bottom = rl.Color{ .r = 190, .g = 180, .b = 160, .a = 255 };

    rl.drawRectangleGradientV(inner_x, inner_y, inner_width, inner_height, beige_top, beige_bottom);

    drawBrushedMetalTexture(inner_x, inner_y, inner_width, inner_height);
    drawBeveledEdges(inner_x, inner_y, inner_width, inner_height);
}

fn drawBrushedMetalTexture(x: i32, y: i32, w: i32, h: i32) void {
    var line_y: i32 = y;
    while (line_y < y + h) : (line_y += 3) {
        const line_alpha: u8 = if (@mod(line_y, 6) == 0) 12 else 6;
        const line_bright = rl.Color{ .r = 235, .g = 225, .b = 205, .a = line_alpha };
        const line_dark = rl.Color{ .r = 180, .g = 170, .b = 150, .a = line_alpha };

        const color = if (@mod(line_y, 6) == 0) line_bright else line_dark;
        rl.drawLine(x, line_y, x + w, line_y, color);
    }
}

fn drawBeveledEdges(x: i32, y: i32, w: i32, h: i32) void {
    const bevel_width: i32 = 10;
    const transparent = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 0 };

    const highlight_start = rl.Color{ .r = 255, .g = 250, .b = 240, .a = 40 };
    const shadow_start = rl.Color{ .r = 80, .g = 70, .b = 60, .a = 35 };

    rl.drawRectangleGradientV(x, y, w, bevel_width, highlight_start, transparent);
    rl.drawRectangleGradientH(x, y, bevel_width, h, highlight_start, transparent);

    rl.drawRectangleGradientV(x, y + h - bevel_width, w, bevel_width, transparent, shadow_start);
    rl.drawRectangleGradientH(x + w - bevel_width, y, bevel_width, h, transparent, shadow_start);
}
