
const builtin = @import("builtin");

pub const enabled = builtin.cpu.arch == .wasm32 and builtin.os.tag == .freestanding;

pub const identifiers = .{
	"a", // _onFrameRequest
	"b", // _onPointerEvent
	"c", // _onKeyboardEvent
};

pub fn declareExports(comptime functions: type) void {
	@export(functions.onFrameRequest, .{ .name = "a" });
	@export(functions.onPointerEvent, .{ .name = "b" });
	@export(functions.onKeyboardEvent, .{ .name = "c" });
}

pub const Imports = if (enabled) struct {
	extern "0" fn a(vb: [*]const u8, vb_size: u32, ib: [*]const u16, indices_count: u32, handle: u32) void;
	pub const drawTriangles = a;

	extern "0" fn b(samples: [*]const f32, length: u32, vol: f32, pan: f32, note: f32, when: f32) void;
	pub const playUserAudioBuffer = b;

	extern "0" fn c(id: u32) void;
	pub const setTexture = c;

	extern "0" fn d(desc_ptr: *const anyopaque) void;
	pub const setTextureData = d;

	extern "0" fn e(id: u32) void;
	pub const setupPass = e;

	extern "0" fn f(msg_ptr: [*]const u8, msg_len: usize) void;
	pub const log = f;

	extern "0" fn g(input: *const anyopaque, output: *anyopaque) void;
	pub const drawText = g;

	extern "0" fn h(x: f32) f32;
	pub const sin = h;

	extern "0" fn i(x: f32) f32;
	pub const cos = i;

	extern "0" fn j(x: f32, y: f32) f32;
	pub const pow = j;

	extern "0" fn k(x: f32, y: f32) f32;
	pub const atan2 = k;

    pub const enabled = true;
} else struct {
    pub const enabled = false;
};
