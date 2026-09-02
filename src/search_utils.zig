const std = @import("std");

pub fn contains_subsequence(haystack: []const u8, needle: []const u8) bool {
    const needle_len = needle.len;
    const haystack_len = haystack.len;
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
