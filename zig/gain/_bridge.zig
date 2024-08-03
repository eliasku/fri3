
const builtin = @import("builtin");

pub const enabled = builtin.cpu.arch == .wasm32 and builtin.os.tag == .freestanding;

pub const identifiers = .{
	"a", // _onSetup
	"b", // _onFirstFrame
	"c", // _onFrame
	"d", // _onPointerEvent
	"e", // _onKeyboardEvent
};

pub fn declareExports(comptime functions: type) void {
	@export(functions.onSetup, .{ .name = "a" });
	@export(functions.onFirstFrame, .{ .name = "b" });
	@export(functions.onFrame, .{ .name = "c" });
	@export(functions.onPointerEvent, .{ .name = "d" });
	@export(functions.onKeyboardEvent, .{ .name = "e" });
}

pub const Imports = if (enabled) struct {
	extern "0" fn a(vb: [*]const u8, vb_size: u32, ib: [*]const u16, indices_count: u32, handle: u32) void;
	pub const drawTriangles = a;

	extern "0" fn b(samples: [*]const f32, length: u32) void;
	pub const playUserAudioBuffer = b;

	extern "0" fn c(id: u32) void;
	pub const setTexture = c;

	extern "0" fn d(desc_ptr: *const anyopaque) void;
	pub const setTextureData = d;

	extern "0" fn e(id: u32) void;
	pub const setupPass = e;

	extern "0" fn f(msg_ptr: [*]const u8, msg_len: usize) void;
	pub const log = f;

	extern "0" fn g(input: *const anyopaque) u32;
	pub const createFont = g;

	extern "0" fn h(id: u32) u32;
	pub const getFontStatus = h;

	extern "0" fn i(input: *const anyopaque, output: *anyopaque) void;
	pub const drawText = i;

	extern "0" fn j(x: f32) f32;
	pub const sin = j;

	extern "0" fn k(x: f32) f32;
	pub const cos = k;

	extern "0" fn l(x: f32, y: f32) f32;
	pub const pow = l;

	extern "0" fn m(x: f32, y: f32) f32;
	pub const atan2 = m;

    pub const enabled = true;
} else struct {
    pub const enabled = false;
};
