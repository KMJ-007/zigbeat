const std = @import("std");
const Parser = @import("parser.zig").Parser;
const AstNode = @import("parser.zig").AstNode;
const testing = std.testing;

pub const BeatType = enum {
    bytebeat, // 8-bit ouput (0-255)
    floatbeat, // output (-1.0 to 1.0)
};

pub const ExpressionType = enum { infix };

pub const SampleRate = enum { rate_8000, rate_11000, rate_22000, rate_32000, rate_44100, rate_48000 };

pub const EvaluatorConfig = struct {
    beat_type: BeatType = .bytebeat,
    expression_type: ExpressionType = .infix,
    sample_rate: SampleRate = .rate_8000,
    expression: std.ArrayList(u8),
};

pub const Evaluator = struct {
    config: EvaluatorConfig,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: EvaluatorConfig) !Evaluator {
        return Evaluator{ .config = config, .allocator = allocator };
    }

    pub fn setExpression(self: *Evaluator, expression: []const u8) !void {
        if (expression.len == 0) return error.EmptyExpression;
        try self.validateExpression(expression);
        self.config.expression.clearRetainingCapacity();
        try self.config.expression.appendSlice(self.allocator, expression);
    }

    pub fn deinit(self: *Evaluator) void {
        self.config.expression.deinit(self.allocator);
    }

    pub fn setBeatType(self: *Evaluator, beat_type: BeatType) void {
        self.config.beat_type = beat_type;
    }

    pub fn setSampleRate(self: *Evaluator, sample_rate: SampleRate) void {
        self.config.sample_rate = sample_rate;
    }

    pub fn evaluate(self: *Evaluator, t: u32) !f32 {
        // parse the expression into AST
        var parser = Parser.init(self.allocator, self.config.expression.items);
        defer parser.deinit();

        const ast_root = try parser.parse();

        // Evaluate the AST
        return try self.evaluateNode(ast_root, t);
    }

    fn validateExpression(self: *Evaluator, expression: []const u8) !void {
        var parser = Parser.init(self.allocator, expression);
        defer parser.deinit();
        _ = parser.parse() catch |err| switch (err) {
            error.NotImplemented => return error.UnsupportedExpression,
            else => return err,
        };
    }

    fn evaluateNode(self: *Evaluator, node: *AstNode, t: u32) !f32 {
        _ = self;
        return switch (node.*) {
            .variable => @floatFromInt(t),
            else => return error.NotImplemented,
        };
    }
};

// test for the evulators
test "evaluator: simple variable t" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "t");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });

    defer evaluator.deinit();

    // when t=0
    try testing.expectEqual(@as(f32, 0.0), evaluator.evaluate(0));

    // when t=256
    try testing.expectEqual(@as(f32, 256.0), evaluator.evaluate(256));
}

test "evaluator: constant number" {
    // 5
}

test "evaluator: simple addition" {
    // t+5
}

test "evaluator: simple subtraction" {
    // t-5
}

test "evaluator: simple multiplication" {
    // t*5
}

test "evaluator: simple division" {
    // t/5
}

test "evaluator: simple modulo" {
    // t%5
}

test "evaluator: bitwise right shift" {
    // t>>5
}

test "evaluator: bitwise left shift" {
    // t<<5
}

test "evaluator: bitwise And" {
    // t&5
}

test "evaluator: bitwise Or" {
    // t|5
}

test "evaluator: bitwise xor" {
    // t ^ 5
}

test "evaluator: or" {
    // t || 4
}

test "evaluator: and" {
    // t && 4
}

test "evaluator: abs" {
    // abs(t)
}

test "evaluator: sqrt" {
    // sqrt(t)
}

test "evaluator: round" {
    // round(t)
}

test "evaluator: tan" {
    // tan(t)
}

test "evaluator: log" {
    // log(t)
}

test "evaluator: exp" {
    // exp(t)
}

test "evaluator: sin" {
    // sin(t)
}

test "evaluator: cos" {
    // cos(t)
}

test "evaluator: floor" {
    // floor(t)
}

test "evaluator: ceil" {
    // ceil(t)
}

test "evaluator: int" {
    // int(t)
}

test "evaluator: min" {
    // min(t, 5)
}

test "evaluator: max" {
    // max(t, 5)
}

test "evaluator: pow" {
    // pow(t, 5)
}

test "evaluator: parenthesis" {
    // (t + 5) * 2
}

test "evaluator: bytebeat example" {
    // (t>>10)*42
}
