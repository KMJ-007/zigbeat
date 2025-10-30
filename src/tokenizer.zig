const std = @import("std");

const TokenType = union(enum) {
    number,
    identifier, // t or function names
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
    logical_or, // ||,
    lparen,
    rparen,
    comma,
    eof,
};

const Token = struct { type: TokenType, value: []const u8 };

const Tokenizer = struct {
    source: []const u8,
    pos: usize,

    pub fn init(source: []const u8) Tokenizer {
        return Tokenizer{ .source = source, .pos = 0 };
    }

    fn next(self: *Tokenizer) Token {
        self.skipWhitespace();

        const start = self.pos;
        const c = self.current() orelse {
            return Token{ .type = .eof, .value = "" };
        };

        switch (c) {
            '0'...'9' => {
                return self.scanNumber(start);
            },
            'a'...'z', 'A'...'Z', '_' => {
                return self.scanIdentifier(start);
            },
            '+' => {
                _ = self.advance();
                return Token{ .type = .add, .value = self.source[start..self.pos] };
            },
            '-' => {
                _ = self.advance();
                return Token{ .type = .sub, .value = self.source[start..self.pos] };
            },
            '*' => {
                _ = self.advance();
                return Token{ .type = .mul, .value = self.source[start..self.pos] };
            },
            '/' => {
                _ = self.advance();
                return Token{ .type = .div, .value = self.source[start..self.pos] };
            },
            '%' => {
                _ = self.advance();
                return Token{ .type = .mod, .value = self.source[start..self.pos] };
            },
            '^' => {
                _ = self.advance();
                return Token{ .type = .bit_xor, .value = self.source[start..self.pos] };
            },
            '<' => {
                _ = self.advance();
                // Check for '<<'
                if (self.current()) |next_char| {
                    if (next_char == '<') {
                        _ = self.advance();
                        return Token{ .type = .bit_shift_left, .value = self.source[start..self.pos] };
                    }
                }
                // Single '<' - for now return EOF (TODO: add error token type or less_than token)
                return Token{ .type = .eof, .value = self.source[start..self.pos] };
            },
            '>' => {
                _ = self.advance();
                // Check for '>>'
                if (self.current()) |next_char| {
                    if (next_char == '>') {
                        _ = self.advance();
                        return Token{ .type = .bit_shift_right, .value = self.source[start..self.pos] };
                    }
                }
                // Single '>' - for now return EOF (TODO: add error token type or greater_than token)
                return Token{ .type = .eof, .value = self.source[start..self.pos] };
            },
            '&' => {
                _ = self.advance();
                // Check for '&&'
                if (self.current()) |next_char| {
                    if (next_char == '&') {
                        _ = self.advance();
                        return Token{ .type = .logical_and, .value = self.source[start..self.pos] };
                    }
                }
                // Single '&' is bit_and
                return Token{ .type = .bit_and, .value = self.source[start..self.pos] };
            },
            '|' => {
                _ = self.advance();
                // Check for '||'
                if (self.current()) |next_char| {
                    if (next_char == '|') {
                        _ = self.advance();
                        return Token{ .type = .logical_or, .value = self.source[start..self.pos] };
                    }
                }
                // Single '|' is bit_or
                return Token{ .type = .bit_or, .value = self.source[start..self.pos] };
            },
            '(' => {
                _ = self.advance();
                return Token{ .type = .lparen, .value = self.source[start..self.pos] };
            },
            ')' => {
                _ = self.advance();
                return Token{ .type = .rparen, .value = self.source[start..self.pos] };
            },
            ',' => {
                _ = self.advance();
                return Token{ .type = .comma, .value = self.source[start..self.pos] };
            },
            else => {
                // Unknown character - TODO: add proper error handling
                _ = self.advance();
                return Token{ .type = .eof, .value = self.source[start..self.pos] };
            },
        }
    }

    fn peek(self: *const Tokenizer) ?u8 {
        if (self.pos + 1 >= self.source.len) return null;
        return self.source[self.pos + 1];
    }

    fn current(self: *const Tokenizer) ?u8 {
        if (self.pos >= self.source.len) {
            return null;
        }
        return self.source[self.pos];
    }

    fn advance(self: *Tokenizer) ?u8 {
        if (self.pos >= self.source.len) return null;
        const c = self.source[self.pos];
        self.pos += 1;
        return c;
    }

    fn skipWhitespace(self: *Tokenizer) void {
        while (self.current()) |c| {
            if ((std.ascii.isWhitespace(c))) {
                _ = self.advance();
            } else break;
        }
    }

    fn scanNumber(self: *Tokenizer, start: usize) Token {
        // Scan all consecutive digits
        while (self.current()) |c| {
            if (std.ascii.isDigit(c) or c == '.') {
                _ = self.advance();
            } else break;
        }
        return Token{ .type = .number, .value = self.source[start..self.pos] };
    }

    fn scanIdentifier(self: *Tokenizer, start: usize) Token {
        // Scan all consecutive alphanumeric characters and underscores
        while (self.current()) |c| {
            if (std.ascii.isAlphanumeric(c) or c == '_') {
                _ = self.advance();
            } else break;
        }
        return Token{ .type = .identifier, .value = self.source[start..self.pos] };
    }
};

test "tokenizer: distinguishes single and double operators" {
    // & vs &&
    var tokenizer1 = Tokenizer.init("&");
    try std.testing.expectEqual(TokenType.bit_and, tokenizer1.next().type);

    var tokenizer2 = Tokenizer.init("&&");
    try std.testing.expectEqual(TokenType.logical_and, tokenizer2.next().type);

    // | vs ||
    var tokenizer3 = Tokenizer.init("|");
    try std.testing.expectEqual(TokenType.bit_or, tokenizer3.next().type);

    var tokenizer4 = Tokenizer.init("||");
    try std.testing.expectEqual(TokenType.logical_or, tokenizer4.next().type);

    // << and >>
    var tokenizer5 = Tokenizer.init("<<");
    try std.testing.expectEqual(TokenType.bit_shift_left, tokenizer5.next().type);

    var tokenizer6 = Tokenizer.init(">>");
    try std.testing.expectEqual(TokenType.bit_shift_right, tokenizer6.next().type);
}

test "tokenizer: real bytebeat expression" {
    var tokenizer = Tokenizer.init("(t >> 10) * 42");

    try std.testing.expectEqual(TokenType.lparen, tokenizer.next().type);
    try std.testing.expectEqual(TokenType.identifier, tokenizer.next().type);
    try std.testing.expectEqual(TokenType.bit_shift_right, tokenizer.next().type);
    try std.testing.expectEqualStrings("10", tokenizer.next().value);
    try std.testing.expectEqual(TokenType.rparen, tokenizer.next().type);
    try std.testing.expectEqual(TokenType.mul, tokenizer.next().type);
    try std.testing.expectEqualStrings("42", tokenizer.next().value);
    try std.testing.expectEqual(TokenType.eof, tokenizer.next().type);
}

test "tokenizer: function with multiple args" {
    var tokenizer = Tokenizer.init("max(t, 5)");

    try std.testing.expectEqualStrings("max", tokenizer.next().value);
    try std.testing.expectEqual(TokenType.lparen, tokenizer.next().type);
    try std.testing.expectEqualStrings("t", tokenizer.next().value);
    try std.testing.expectEqual(TokenType.comma, tokenizer.next().type);
    try std.testing.expectEqualStrings("5", tokenizer.next().value);
    try std.testing.expectEqual(TokenType.rparen, tokenizer.next().type);
}

test "tokenizer: decimal numbers" {
    var tokenizer = Tokenizer.init("3.14");
    try std.testing.expectEqualStrings("3.14", tokenizer.next().value);
}

test "tokenizer: all arithmetic operators" {
    var tokenizer = Tokenizer.init("+ - * / %");
    try std.testing.expectEqual(TokenType.add, tokenizer.next().type);
    try std.testing.expectEqual(TokenType.sub, tokenizer.next().type);
    try std.testing.expectEqual(TokenType.mul, tokenizer.next().type);
    try std.testing.expectEqual(TokenType.div, tokenizer.next().type);
    try std.testing.expectEqual(TokenType.mod, tokenizer.next().type);
}
