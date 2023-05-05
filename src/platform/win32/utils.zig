const std = @import("std");
/// use only with zero terminated strings.
/// returns true if the 2 slices are equals.
pub fn wide_str_cmp(str_a: []const u16, str_b: []const u16) bool {
    var i: usize = 0;
    while (str_a.ptr[i] != 0 and str_b.ptr[i] != 0) {
        if (str_a.ptr[i] != str_b.ptr[i]) {
            return false;
        }
        i += 1;
    }
    // assert that we reached the end of both strings.
    if (str_a.ptr[i] != str_b.ptr[i]) {
        return false;
    }
    return true;
}

// pub fn str_cmp(str_a: []const u8, str_b: []const u8) bool {
//     var i: usize = 0;
//     while (str_a.ptr[i] != 0 and str_b.ptr[i] != 0) {
//         if (str_a.ptr[i] != str_b.ptr[i]) {
//             return false;
//         }
//         i += 1;
//     }
//     // assert that we reached the end of both strings.
//     if (str_a.ptr[i] != str_b.ptr[i]) {
//         return false;
//     }
//     return true;
// }
