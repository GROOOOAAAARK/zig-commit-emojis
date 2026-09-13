const std = @import("std");

/// Case-insensitive contiguous substring match.
pub fn contains(haystack: []const u8, needle: []const u8) bool {
    const needle_len = needle.len;
    const haystack_len = haystack.len;
    if (needle_len == 0) {
        return true;
    }
    if (needle_len > haystack_len) {
        return false;
    }
    var buf1: [1024]u8 = undefined;
    var buf2: [1024]u8 = undefined;
    const lower_needle = std.ascii.lowerString(&buf1, needle);
    for (0..haystack_len - needle_len + 1) |i| {
        const lower_haystack = std.ascii.lowerString(&buf2, haystack[i .. i + needle_len]);
        if (std.mem.eql(u8, lower_haystack, lower_needle)) {
            return true;
        }
    }
    return false;
}

/// Case-insensitive subsequence match: every character of `needle` appears
/// in `haystack` in order, not necessarily adjacent.
pub fn contains_subsequence(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) {
        return true;
    }
    var hay_idx: usize = 0;
    for (needle) |n| {
        const lower_n = std.ascii.toLower(n);
        var found = false;
        while (hay_idx < haystack.len) {
            if (std.ascii.toLower(haystack[hay_idx]) == lower_n) {
                found = true;
                break;
            }
            hay_idx += 1;
        }
        if (!found) return false;
        hay_idx += 1;
    }
    return true;
}

test "contains: contiguous case-insensitive substring" {
    try std.testing.expect(contains("Fix a bug.", "fix"));
    try std.testing.expect(contains("Fix a bug.", "BUG"));
    try std.testing.expect(contains("Fix a bug.", ""));
    try std.testing.expect(!contains("Fix a bug.", "fx"));
    try std.testing.expect(!contains("Fix a bug.", "bug x"));
    try std.testing.expect(!contains("Fix", "Fix a bug."));
}

test "contains_subsequence: ordered non-adjacent match" {
    try std.testing.expect(contains_subsequence("Fix a bug.", "fx"));
    try std.testing.expect(contains_subsequence("Fix a bug.", "fb"));
    try std.testing.expect(contains_subsequence("Fix a bug.", "bug"));
    try std.testing.expect(contains_subsequence("Fix a bug.", ""));
    try std.testing.expect(!contains_subsequence("Fix a bug.", "bf"));
    try std.testing.expect(!contains_subsequence("Fix a bug.", "bb"));
    try std.testing.expect(contains_subsequence("Improve performance.", "i p"));
    try std.testing.expect(!contains_subsequence("Improve performance.", "mmp"));
}
