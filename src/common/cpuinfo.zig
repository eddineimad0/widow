const std = @import("std");
const builtin = @import("builtin");
const utils = @import("utils");

const bits = utils.bits;

pub const CpuX86 = struct {
    x86_cpu_features: [6]u32 = [6]u32{ 0, 0, 0, 0, 0, 0 },
    highest_function_id: u32 = 0,
    highest_ex_function_id: u32 = 0,
    cpu_brand_string: [0x40]u8 = [11]u8{ 'U', 'n', 'k', 'n', 'o', 'w', 'n', ' ', 'x', '8', '6' } ++ ([1]u8{0} ** 0x35),

    const FUNC_1_ECX_INDX = 0;
    const FUNC_1_EDX_INDX = 1;
    const FUNC_7_EBX_INDX = 2;
    const FUNC_7_ECX_INDX = 3;
    const FUNC_81_ECX_INDX = 4;
    const FUNC_81_EDX_INDX = 5;

    const Self = @This();

    /// Checks if the `CPUID` instruction is supported on the current x86
    /// platform, if you have anything newer than a pentium 4 then the `CPUID`
    /// instruction is supported.
    fn x86CPUIdCapable() bool {
        switch (builtin.cpu.arch) {
            .x86 => {
                return asm volatile (
                    \\ pushfl
                    \\ popl %%eax
                    \\ movl %%eax, %%ecx
                    \\ xorl $0x200000, %%eax    # flip bit 21
                    \\ pushl %%eax
                    \\ popfl
                    \\ pushfl
                    \\ popl %%eax
                    \\ xorl %%ecx, %%eax
                    \\ jnz set_true
                    \\ xorl %%eax, %%eax
                    \\ jmp exit
                    \\set_true:
                    \\ movl $1, %%eax
                    \\exit:
                    : [ret] "={eax}" (-> bool),
                    :
                    : .{ .eax = true, .ecx = true });
            },
            .x86_64 => {
                return asm volatile (
                    \\ pushfq
                    \\ popq %%rax
                    \\ movq %%rax, %%rcx
                    \\ xorl $0x200000, %%eax    # flip bit 21
                    \\ pushq %%rax
                    \\ popfq
                    \\ pushfq
                    \\ popq %%rax
                    \\ xorl %%ecx, %%eax
                    \\ jnz set_true
                    \\ xorq %%rax, %%rax
                    \\ jmp exit
                    \\set_true:
                    \\ movq $1, %%rax
                    \\exit:
                    : [ret] "={rax}" (-> bool),
                    :
                    : .{ .rax = true, .rcx = true });
            },
            else => false,
        }
    }

    fn x86CPUId(func: u32, noalias a: *u32, noalias b: *u32, noalias c: *u32, noalias d: *u32) void {
        // WARN: the inline assembly feature is quite unstable so be aware of this function
        switch (builtin.cpu.arch) {
            .x86 => {
                return asm volatile (
                    \\ pushl %%edx
                    \\ pushl %%ecx
                    \\ pushl %%ebx
                    \\ xorl %%ecx, %%ecx
                    \\ cpuid
                    \\ movl %%eax, (%%edi)
                    \\ popl %%edi
                    \\ movl %%ebx, (%%edi)
                    \\ popl %%edi
                    \\ movl %%ecx, (%%edi)
                    \\ popl %%edi
                    \\ movl %%edx, (%%edi)
                    :
                    : [func] "{eax}" (func),
                      [a] "{edi}" (a),
                      [b] "{ebx}" (b),
                      [c] "{ecx}" (c),
                      [d] "{edx}" (d),
                    : .{ .eax = true, .edi = true, .ebx = true, .ecx = true, .edx = true });
            },
            .x86_64 => {
                return asm volatile (
                    \\ movq %%rdi, %%rax
                    \\ movq %%rdx, %%r10
                    \\ xorq %%rdx, %%rdx
                    \\ movq %%rcx, %%r9
                    \\ xorq %%rcx, %%rcx
                    \\ cpuid
                    \\ movl %%eax, (%%rsi)
                    \\ movl %%ebx, (%%r10)
                    \\ movl %%ecx, (%%r9)
                    \\ movl %%edx, (%%r8)
                    :
                    : [func] "{rdi}" (func),
                      [a] "{rsi}" (a),
                      [b] "{rdx}" (b),
                      [c] "{rcx}" (c),
                      [d] "{r8}" (d),
                    : .{ .rax = true, .rbx = true, .r9 = true, .r10 = true, .rdi = true, .rsi = true, .rdx = true, .rcx = true, .r8 = true });
            },
            else => @compileError("Unsupported CPU Arch"),
        }
    }

    /// Should be called first to query the CPU features.
    pub fn fetchCPUFeatures(self: *Self) void {
        var a: u32, var b: u32, var c: u32, var d: u32 = .{ 0, 0, 0, 0 };
        if (x86CPUIdCapable()) {
            x86CPUId(
                0,
                &a,
                &b,
                &c,
                &d,
            );

            self.highest_function_id = a;

            if (self.highest_function_id >= 1) {
                x86CPUId(
                    1,
                    &a,
                    &b,
                    &c,
                    &d,
                );
                self.x86_cpu_features[FUNC_1_ECX_INDX] = c;
                self.x86_cpu_features[FUNC_1_EDX_INDX] = d;
            }

            if (self.highest_function_id >= 7) {
                x86CPUId(
                    7,
                    &a,
                    &b,
                    &c,
                    &d,
                );
                self.x86_cpu_features[FUNC_7_EBX_INDX] = b;
                self.x86_cpu_features[FUNC_7_ECX_INDX] = c;
            }

            x86CPUId(
                0x80000000,
                &a,
                &b,
                &c,
                &d,
            );

            self.highest_ex_function_id = a;

            if (self.highest_ex_function_id >= 0x80000001) {
                x86CPUId(
                    0x80000001,
                    &a,
                    &b,
                    &c,
                    &d,
                );
                self.x86_cpu_features[FUNC_81_ECX_INDX] = c;
                self.x86_cpu_features[FUNC_81_EDX_INDX] = d;
            }

            if (self.highest_ex_function_id >= 0x80000004) {
                x86CPUId(
                    0x80000002,
                    &a,
                    &b,
                    &c,
                    &d,
                );
                @memcpy(self.cpu_brand_string[0..4], @as([*]u8, @ptrCast(&a)));
                @memcpy(self.cpu_brand_string[4..8], @as([*]u8, @ptrCast(&b)));
                @memcpy(self.cpu_brand_string[8..12], @as([*]u8, @ptrCast(&c)));
                @memcpy(self.cpu_brand_string[12..16], @as([*]u8, @ptrCast(&d)));

                x86CPUId(
                    0x80000003,
                    &a,
                    &b,
                    &c,
                    &d,
                );
                @memcpy(self.cpu_brand_string[16..20], @as([*]u8, @ptrCast(&a)));
                @memcpy(self.cpu_brand_string[20..24], @as([*]u8, @ptrCast(&b)));
                @memcpy(self.cpu_brand_string[24..28], @as([*]u8, @ptrCast(&c)));
                @memcpy(self.cpu_brand_string[28..32], @as([*]u8, @ptrCast(&d)));

                x86CPUId(
                    0x80000004,
                    &a,
                    &b,
                    &c,
                    &d,
                );
                @memcpy(self.cpu_brand_string[32..36], @as([*]u8, @ptrCast(&a)));
                @memcpy(self.cpu_brand_string[36..40], @as([*]u8, @ptrCast(&b)));
                @memcpy(self.cpu_brand_string[40..44], @as([*]u8, @ptrCast(&c)));
                @memcpy(self.cpu_brand_string[44..48], @as([*]u8, @ptrCast(&d)));
            }
        }
    }

    /// Returns true if cpu supports SSE instructions
    pub inline fn hasSSE(self: *const Self) bool {
        return bits.isBitSet(self.x86_cpu_features[FUNC_1_EDX_INDX], 25);
    }

    /// Returns true if cpu supports SSE2 instructions
    pub inline fn hasSSE2(self: *const Self) bool {
        return bits.isBitSet(self.x86_cpu_features[FUNC_1_EDX_INDX], 26);
    }

    /// Returns true if cpu supports SSE3 instructions
    pub inline fn hasSSE3(self: *const Self) bool {
        return bits.isBitSet(self.x86_cpu_features[FUNC_1_ECX_INDX], 0);
    }

    /// Returns true if cpu supports SSSE3 instructions
    pub inline fn hasSSSE3(self: *const Self) bool {
        return bits.isBitSet(self.x86_cpu_features[FUNC_1_ECX_INDX], 9);
    }

    /// Returns true if cpu supports SSE4.1 instructions
    pub inline fn hasSSE41(self: *const Self) bool {
        return bits.isBitSet(self.x86_cpu_features[FUNC_1_ECX_INDX], 19);
    }

    /// Returns true if cpu supports SSE4.2 instructions
    pub inline fn hasSSE42(self: *const Self) bool {
        return bits.isBitSet(self.x86_cpu_features[FUNC_1_ECX_INDX], 20);
    }

    /// Returns true if cpu supports SSE instructions
    pub inline fn hasMMX(self: *const Self) bool {
        return bits.isBitSet(self.x86_cpu_features[FUNC_1_EDX_INDX], 23);
    }

    /// Returns true if cpu supports AVX instructions
    pub inline fn hasAVX(self: *const Self) bool {
        return bits.isBitSet(self.x86_cpu_features[FUNC_1_ECX_INDX], 28);
    }

    /// Returns true if cpu supports AVX2 instructions
    pub inline fn hasAVX2(self: *const Self) bool {
        return bits.isBitSet(self.x86_cpu_features[FUNC_7_EBX_INDX], 5);
    }

    /// Returns true if cpu supports AVX512F instructions
    pub inline fn hasAVX512F(self: *const Self) bool {
        return bits.isBitSet(self.x86_cpu_features[FUNC_7_EBX_INDX], 16);
    }

    /// Returns true if cpu supports AVX512PF instructions
    pub inline fn hasAVX512PF(self: *const Self) bool {
        return bits.isBitSet(self.x86_cpu_features[FUNC_7_EBX_INDX], 26);
    }

    /// Returns true if cpu supports AVX512ER instructions
    pub inline fn hasAVX512ER(self: *const Self) bool {
        return bits.isBitSet(self.x86_cpu_features[FUNC_7_EBX_INDX], 27);
    }

    /// Returns true if cpu supports AVX512CD instructions
    pub inline fn hasAVX512CD(self: *const Self) bool {
        return bits.isBitSet(self.x86_cpu_features[FUNC_7_EBX_INDX], 28);
    }

    /// Returns true if cpu supports SHA instructions
    pub inline fn hasSHA(self: *const Self) bool {
        return bits.isBitSet(self.x86_cpu_features[FUNC_7_EBX_INDX], 29);
    }

    /// Returns true if cpu supports AES instructions
    pub inline fn hasAES(self: *const Self) bool {
        return bits.isBitSet(self.x86_cpu_features[FUNC_1_ECX_INDX], 25);
    }

    pub inline fn getCPUBrand(self: *const Self) [*:0]const u8 {
        return @ptrCast(&self.cpu_brand_string);
    }
};

test "x86 features" {
    const testing = std.testing;
    var cpu_info = CpuX86{};
    try testing.expect(cpu_info.fetchCPUFeatures());
}

//------------
// ARM
//------------
pub const CpuArm = struct {
    // TODO: Neon and cpu info
};
