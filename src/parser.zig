const std = @import("std");

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
    // need to use logical cause and or are resvered keywords in zig
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
    source: [] const u8,

    pub fn init(allocator: std.mem.Allocator,source: []const u8) Parser {
        return Parser{
            .allocator = std.heap.ArenaAllocator.init(allocator),
            .source = source,
        };
    }

    pub fn deinit(self: *Parser) void {
        self.allocator.deinit();
    }

    pub fn parse(self: *Parser) !*AstNode {
        if(std.mem.eql(u8, self.source, "t")) {
            const node = try self.allocator.allocator().create(AstNode);
            node.* = .variable;
            return node;
        }

        return error.NotImplemented;
    }

};
