
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
	pub const setupPass = c;

	extern "0" fn d(msg_ptr: [*]const u8, msg_len: usize) void;
	pub const log = d;

	extern "0" fn e(x: f32) f32;
	pub const sin = e;

	extern "0" fn f(x: f32) f32;
	pub const cos = f;

	extern "0" fn g(x: f32, y: f32) f32;
	pub const pow = g;

	extern "0" fn h(x: f32, y: f32) f32;
	pub const atan2 = h;

	extern "0" fn i(handle: i32, x: i32, y: i32, color: u32, size: i32, msg_ptr: [*]const u8, msg_len: usize) void;
	pub const text = i;

    pub const enabled = true;
} else struct {
    pub const enabled = false;
};
