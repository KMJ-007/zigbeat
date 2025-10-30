const std = @import("std");

const Tokenizer = @import("tokenizer.zig");

pub const BinaryOp = enum {
    add, // +
    sub, // -
    mul, // *
    div, // /
    mod, // %
    bit_and, // &
    bit_or, // |
    bit_xor, // ^
    bit_shift_left, // <<
    bit_shift_right, // >>
    // need to use logical cause or, and are resvered keywords in zig
    logical_and, // &&
    logical_or, // ||
};

pub const FunctionType = enum { abs, sqrt, round, log, exp, sin, cos, tan, floor, ceil, min, max, pow };

pub const AstNode = union(enum) {
    number: f32,
    variable,
    binary_op: struct {
        left: *AstNode,
        right: *AstNode,
        op: BinaryOp,
    },
    function: struct {
        name: FunctionType,
        args: []*AstNode,
    },
};

pub const Parser = struct {
    // going to use arena allocator so we can free it at the end
    allocator: std.heap.ArenaAllocator,
    tokenizer: Tokenizer.Tokenizer,
    current_token: Tokenizer.Token,

    pub fn init(allocator: std.mem.Allocator, source: []const u8) Parser {
        var tokenizer = Tokenizer.Tokenizer.init(source);
        const first_token = tokenizer.next();
        return Parser{
            .allocator = std.heap.ArenaAllocator.init(allocator),
            .tokenizer = tokenizer,
            .current_token = first_token,
        };
    }

    pub fn deinit(self: *Parser) void {
        self.allocator.deinit();
    }

    pub fn parse(self: *Parser) !*AstNode {
        return try self.parseExpression(0);
    }

    fn parseExpression(self: *Parser, min_bp: u8) error{ OutOfMemory, InvalidCharacter, ExpectedClosingParen, ExpectedOpeningParen, FunctionNeedsArguments, UnexpectedToken, UnknownFunction, UnknownOperator, NotAnOperator }!*AstNode {
        var lhs = try self.parsePrimary();

        while (self.current_token.precedence()) |bp| {
            // if operator is too weak
            if (bp.l_bp < min_bp) break;

            const op = try self.current_token.toBinaryOp();
            // consume consume consume, we are gone consume it, yayayayayaya!
            self.advance();

            // parse right side with higher binding power
            const rhs = try self.parseExpression(bp.r_bp);

            const node = try self.allocator.allocator().create(AstNode);
            node.* = AstNode{ .binary_op = .{ .left = lhs, .right = rhs, .op = op } };
            lhs = node;
        }
        return lhs;
    }

    fn parsePrimary(self: *Parser) !*AstNode {
        const token = self.current_token;

        switch (token.type) {
            .number => {
                self.advance();
                const value = try std.fmt.parseFloat(f32, token.value);
                const node = try self.allocator.allocator().create(AstNode);
                node.* = AstNode{ .number = value };
                return node;
            },
            .identifier => {
                // check if it's the variable 't'
                if (std.mem.eql(u8, token.value, "t")) {
                    self.advance();
                    const node = try self.allocator.allocator().create(AstNode);
                    node.* = .variable;
                    return node;
                } else {
                    // it's function call
                    return try self.parseFunctionCall();
                }
            },
            .lparen => {
                self.advance(); // consume '('
                const expr = try self.parseExpression(0); // Parse inner expression

                if (self.current_token.type != .rparen) {
                    return error.ExpectedClosingParen;
                }
                self.advance(); // consume ')'

                return expr;
            },
            else => {
                return error.UnexpectedToken;
            },
        }
    }

    // parsing function calls: sin, max, etc....
    fn parseFunctionCall(self: *Parser) !*AstNode {
        const name_token = self.current_token;
        // consume function name
        self.advance();

        if (self.current_token.type != .lparen) {
            return error.ExpectedOpeningParen;
        }

        // consume '('
        const func_type = try parseFunctionName(name_token.value);

        // parse arguments
        var args = std.ArrayList(*AstNode).empty;

        // empty arg
        if(self.current_token.type == .rparen){
            return error.FunctionNeedsArguments;
        }

        try args.append(self.allocator.allocator(), try self.parseExpression(0));

        // parse remaining args
        while(self.current_token.type == .comma) {
            self.advance(); // consume ','
            try args.append(self.allocator.allocator(), try self.parseExpression(0));
        }

        if(self.current_token.type != .rparen){
            return error.ExpectedClosingParen;
        }
        self.advance(); // consume ')'

        // node node function node
        const node = try self.allocator.allocator().create(AstNode);
        node.* = AstNode{
            .function = .{
                .name = func_type,
                .args = try args.toOwnedSlice(self.allocator.allocator()),
            }
        };
        return node;
    }

    fn advance(self: *Parser) void {
        self.current_token = self.tokenizer.next();
    }
};
fn parseFunctionName(name: []const u8) !FunctionType {
    const map = std.StaticStringMap(FunctionType).initComptime( .{
        .{ "abs", .abs },
        .{ "sqrt", .sqrt },
        .{ "round", .round },
        .{ "log", .log },
        .{ "exp", .exp },
        .{ "sin", .sin },
        .{ "cos", .cos },
        .{ "tan", .tan },
        .{ "floor", .floor },
        .{ "ceil", .ceil },
        .{ "min", .min },
        .{ "max", .max },
        .{ "pow", .pow },
    });

    return map.get(name) orelse error.UnknownFunction;
}

test "parser: simple number" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator, "42");
    defer parser.deinit();

    const ast = try parser.parse();
    try std.testing.expectEqual(@as(f32, 42.0), ast.number);
}

test "parser: variable t" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator, "t");
    defer parser.deinit();

    const ast = try parser.parse();
    try std.testing.expect(ast.* == .variable);
}

test "parser: simple addition" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator, "t + 5");
    defer parser.deinit();

    const ast = try parser.parse();
    try std.testing.expect(ast.* == .binary_op);
    try std.testing.expectEqual(BinaryOp.add, ast.binary_op.op);
}

test "parser: precedence test" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator, "2 + 3 * 4");
    defer parser.deinit();

    const ast = try parser.parse();
    // Should parse as: 2 + (3 * 4)
    try std.testing.expectEqual(BinaryOp.add, ast.binary_op.op);
    try std.testing.expectEqual(@as(f32, 2.0), ast.binary_op.left.number);
    try std.testing.expectEqual(BinaryOp.mul, ast.binary_op.right.binary_op.op);
}

test "parser: bytebeat expression" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator, "(t >> 10) * 42");
    defer parser.deinit();

    const ast = try parser.parse();
    try std.testing.expectEqual(BinaryOp.mul, ast.binary_op.op);
}
