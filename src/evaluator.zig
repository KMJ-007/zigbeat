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
    sample_rate: SampleRate = .rate_48000,
    expression: std.ArrayList(u8),
};

pub const Evaluator = struct {
    config: EvaluatorConfig,
    allocator: std.mem.Allocator,
    ast_arena: std.heap.ArenaAllocator,
    cached_ast: ?*AstNode,

    pub fn init(allocator: std.mem.Allocator, config: EvaluatorConfig) !Evaluator {
        return Evaluator{
            .config = config,
            .allocator = allocator,
            .ast_arena = std.heap.ArenaAllocator.init(allocator),
            .cached_ast = null,
        };
    }

    pub fn setExpression(self: *Evaluator, expression: []const u8) !void {
        if (expression.len == 0) return error.EmptyExpression;

        _ = self.ast_arena.reset(.retain_capacity);
        var parser = Parser.init(self.ast_arena.allocator(), expression);
        self.cached_ast = try parser.parse();

        self.config.expression.clearRetainingCapacity();
        try self.config.expression.appendSlice(self.allocator, expression);
    }

    pub fn deinit(self: *Evaluator) void {
        self.ast_arena.deinit();
        self.config.expression.deinit(self.allocator);
    }

    pub fn setBeatType(self: *Evaluator, beat_type: BeatType) void {
        self.config.beat_type = beat_type;
    }

    pub fn setSampleRate(self: *Evaluator, sample_rate: SampleRate) void {
        self.config.sample_rate = sample_rate;
    }

    pub fn evaluate(self: *Evaluator, t: u32) !f32 {
        if (self.cached_ast) |ast| {
            return try self.evaluateNode(ast, t);
        }
        return error.NoExpression;
    }

    fn evaluateNode(self: *Evaluator, node: *AstNode, t: u32) !f32 {
        return switch (node.*) {
            .variable => @floatFromInt(t),
            .number => |val| return val,
            .binary_op => |bin_op| {
                const left = try self.evaluateNode(bin_op.left, t);
                const right = try self.evaluateNode(bin_op.right, t);

                return switch (bin_op.op) {
                    .add => left + right,
                    .sub => left - right,
                    .mul => left * right,
                    .div => if (right == 0.0) 0.0 else left / right,
                    .mod => if (right == 0.0) 0.0 else @mod(left, right),
                    .bit_shift_right => blk: {
                        const l: i32 = @intFromFloat(left);
                        const r: u5 = @intCast(@mod(@as(i32, @intFromFloat(right)), 32));
                        break :blk @floatFromInt(l >> r);
                    },
                    .bit_shift_left => blk: {
                        const l: i32 = @intFromFloat(left);
                        const r: u5 = @intCast(@mod(@as(i32, @intFromFloat(right)), 32));
                        break :blk @floatFromInt(l << r);
                    },
                    .bit_and => blk: {
                        const l: i32 = @intFromFloat(left);
                        const r: i32 = @intFromFloat(right);
                        break :blk @floatFromInt(l & r);
                    },
                    .bit_or => blk: {
                        const l: i32 = @intFromFloat(left);
                        const r: i32 = @intFromFloat(right);
                        break :blk @floatFromInt(l | r);
                    },
                    .bit_xor => blk: {
                        const l: i32 = @intFromFloat(left);
                        const r: i32 = @intFromFloat(right);
                        break :blk @floatFromInt(l ^ r);
                    },

                    // Logical (return 1.0 or 0.0)
                    .logical_and => if (left != 0.0 and right != 0.0) 1.0 else 0.0,
                    .logical_or => if (left != 0.0 or right != 0.0) 1.0 else 0.0,
                };
            },
            .function => |func| {
                // evaluate args first
                var arg_vals = try self.allocator.alloc(f32, func.args.len);
                defer self.allocator.free(arg_vals);

                for (func.args, 0..) |arg, i| {
                    arg_vals[i] = try self.evaluateNode(arg, t);
                }

                // now apply the function
                return switch (func.name) {
                    .sin => @sin(arg_vals[0]),
                    .cos => @cos(arg_vals[0]),
                    .abs => @abs(arg_vals[0]),
                    .sqrt => if (arg_vals[0] < 0) 0.0 else @sqrt(arg_vals[0]),
                    .round => @round(arg_vals[0]),
                    .log => @log(arg_vals[0]),
                    .exp => @exp(arg_vals[0]),
                    .tan => @tan(arg_vals[0]),
                    .floor => @floor(arg_vals[0]),
                    .ceil => @ceil(arg_vals[0]),
                    .min => @min(arg_vals[0], arg_vals[1]),
                    .max => @max(arg_vals[0], arg_vals[1]),
                };
            },
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
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "42");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 42.0), try evaluator.evaluate(0));
    try testing.expectEqual(@as(f32, 42.0), try evaluator.evaluate(100));
}

test "evaluator: simple addition" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "t + 5");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 5.0), try evaluator.evaluate(0));
    try testing.expectEqual(@as(f32, 15.0), try evaluator.evaluate(10));
    try testing.expectEqual(@as(f32, 105.0), try evaluator.evaluate(100));
}

test "evaluator: simple subtraction" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "t - 5");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, -5.0), try evaluator.evaluate(0));
    try testing.expectEqual(@as(f32, 5.0), try evaluator.evaluate(10));
    try testing.expectEqual(@as(f32, 95.0), try evaluator.evaluate(100));
}

test "evaluator: simple multiplication" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "t * 5");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 0.0), try evaluator.evaluate(0));
    try testing.expectEqual(@as(f32, 50.0), try evaluator.evaluate(10));
    try testing.expectEqual(@as(f32, 500.0), try evaluator.evaluate(100));
}

test "evaluator: simple division" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "t / 5");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 0.0), try evaluator.evaluate(0));
    try testing.expectEqual(@as(f32, 2.0), try evaluator.evaluate(10));
    try testing.expectEqual(@as(f32, 20.0), try evaluator.evaluate(100));
}

test "evaluator: simple modulo" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "t % 256");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 0.0), try evaluator.evaluate(0));
    try testing.expectEqual(@as(f32, 10.0), try evaluator.evaluate(10));
    try testing.expectEqual(@as(f32, 0.0), try evaluator.evaluate(256));
    try testing.expectEqual(@as(f32, 1.0), try evaluator.evaluate(257));
}

test "evaluator: bitwise right shift" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "t >> 5");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 0.0), try evaluator.evaluate(0));
    try testing.expectEqual(@as(f32, 1.0), try evaluator.evaluate(32));
    try testing.expectEqual(@as(f32, 2.0), try evaluator.evaluate(64));
    try testing.expectEqual(@as(f32, 32.0), try evaluator.evaluate(1024));
}

test "evaluator: bitwise left shift" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "t << 2");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 0.0), try evaluator.evaluate(0));
    try testing.expectEqual(@as(f32, 4.0), try evaluator.evaluate(1));
    try testing.expectEqual(@as(f32, 20.0), try evaluator.evaluate(5));
    try testing.expectEqual(@as(f32, 40.0), try evaluator.evaluate(10));
}

test "evaluator: bitwise And" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "t & 15");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 0.0), try evaluator.evaluate(0));
    try testing.expectEqual(@as(f32, 10.0), try evaluator.evaluate(10));
    try testing.expectEqual(@as(f32, 0.0), try evaluator.evaluate(16));
    try testing.expectEqual(@as(f32, 1.0), try evaluator.evaluate(17));
}

test "evaluator: bitwise Or" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "t | 8");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 8.0), try evaluator.evaluate(0));
    try testing.expectEqual(@as(f32, 9.0), try evaluator.evaluate(1));
    try testing.expectEqual(@as(f32, 10.0), try evaluator.evaluate(2));
    try testing.expectEqual(@as(f32, 12.0), try evaluator.evaluate(4));
}

test "evaluator: bitwise xor" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "t ^ 255");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 255.0), try evaluator.evaluate(0));
    try testing.expectEqual(@as(f32, 254.0), try evaluator.evaluate(1));
    try testing.expectEqual(@as(f32, 245.0), try evaluator.evaluate(10));
    try testing.expectEqual(@as(f32, 0.0), try evaluator.evaluate(255));
}

test "evaluator: or" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "t || 4");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 1.0), try evaluator.evaluate(0)); // 0 || 4 = true
    try testing.expectEqual(@as(f32, 1.0), try evaluator.evaluate(1)); // 1 || 4 = true
    try testing.expectEqual(@as(f32, 1.0), try evaluator.evaluate(10)); // 10 || 4 = true
}

test "evaluator: and" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "t && 4");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 0.0), try evaluator.evaluate(0)); // 0 && 4 = false
    try testing.expectEqual(@as(f32, 1.0), try evaluator.evaluate(1)); // 1 && 4 = true
    try testing.expectEqual(@as(f32, 1.0), try evaluator.evaluate(10)); // 10 && 4 = true
}

test "evaluator: abs" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "abs(t - 50)");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 50.0), try evaluator.evaluate(0));
    try testing.expectEqual(@as(f32, 0.0), try evaluator.evaluate(50));
    try testing.expectEqual(@as(f32, 50.0), try evaluator.evaluate(100));
}

test "evaluator: sqrt" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "sqrt(t)");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 0.0), try evaluator.evaluate(0));
    try testing.expectEqual(@as(f32, 3.0), try evaluator.evaluate(9));
    try testing.expectEqual(@as(f32, 4.0), try evaluator.evaluate(16));
    try testing.expectEqual(@as(f32, 10.0), try evaluator.evaluate(100));
}

test "evaluator: round" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "round(t / 10)");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 0.0), try evaluator.evaluate(0));
    try testing.expectEqual(@as(f32, 0.0), try evaluator.evaluate(4));
    try testing.expectEqual(@as(f32, 1.0), try evaluator.evaluate(5));
    try testing.expectEqual(@as(f32, 1.0), try evaluator.evaluate(9));
}

test "evaluator: tan" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "tan(0)");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 0.0), try evaluator.evaluate(0));
}

test "evaluator: log" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "log(t + 1)");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    const result = try evaluator.evaluate(0); // log(1) = 0
    try testing.expectApproxEqAbs(@as(f32, 0.0), result, 0.0001);
}

test "evaluator: exp" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "exp(0)");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    const result = try evaluator.evaluate(0); // exp(0) = 1
    try testing.expectApproxEqAbs(@as(f32, 1.0), result, 0.0001);
}

test "evaluator: sin" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "sin(0)");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    const result = try evaluator.evaluate(0); // sin(0) = 0
    try testing.expectApproxEqAbs(@as(f32, 0.0), result, 0.0001);
}

test "evaluator: cos" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "cos(0)");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    const result = try evaluator.evaluate(0); // cos(0) = 1
    try testing.expectApproxEqAbs(@as(f32, 1.0), result, 0.0001);
}

test "evaluator: floor" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "floor(t / 10)");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 0.0), try evaluator.evaluate(0));
    try testing.expectEqual(@as(f32, 0.0), try evaluator.evaluate(9));
    try testing.expectEqual(@as(f32, 1.0), try evaluator.evaluate(10));
    try testing.expectEqual(@as(f32, 1.0), try evaluator.evaluate(19));
}

test "evaluator: ceil" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "ceil(t / 10)");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 0.0), try evaluator.evaluate(0));
    try testing.expectEqual(@as(f32, 1.0), try evaluator.evaluate(1));
    try testing.expectEqual(@as(f32, 1.0), try evaluator.evaluate(9));
    try testing.expectEqual(@as(f32, 1.0), try evaluator.evaluate(10));
}

test "evaluator: int" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "floor(t / 10)");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 2.0), try evaluator.evaluate(25));
}

test "evaluator: min" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "min(t, 100)");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 0.0), try evaluator.evaluate(0));
    try testing.expectEqual(@as(f32, 50.0), try evaluator.evaluate(50));
    try testing.expectEqual(@as(f32, 100.0), try evaluator.evaluate(100));
    try testing.expectEqual(@as(f32, 100.0), try evaluator.evaluate(200));
}

test "evaluator: max" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "max(t, 100)");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 100.0), try evaluator.evaluate(0));
    try testing.expectEqual(@as(f32, 100.0), try evaluator.evaluate(50));
    try testing.expectEqual(@as(f32, 100.0), try evaluator.evaluate(100));
    try testing.expectEqual(@as(f32, 200.0), try evaluator.evaluate(200));
}

test "evaluator: parenthesis" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "(t + 5) * 2");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 10.0), try evaluator.evaluate(0)); // (0+5)*2
    try testing.expectEqual(@as(f32, 20.0), try evaluator.evaluate(5)); // (5+5)*2
    try testing.expectEqual(@as(f32, 30.0), try evaluator.evaluate(10)); // (10+5)*2
}

test "evaluator: bytebeat example" {
    const allocator = testing.allocator;
    var expr = std.ArrayList(u8).empty;
    try expr.appendSlice(allocator, "(t >> 10) * 42");

    var evaluator = try Evaluator.init(allocator, .{
        .expression = expr,
        .beat_type = .bytebeat,
    });
    defer evaluator.deinit();

    try testing.expectEqual(@as(f32, 0.0), try evaluator.evaluate(0)); // (0>>10)*42 = 0
    try testing.expectEqual(@as(f32, 42.0), try evaluator.evaluate(1024)); // (1024>>10)*42 = 1*42
    try testing.expectEqual(@as(f32, 84.0), try evaluator.evaluate(2048)); // (2048>>10)*42 = 2*42
}
