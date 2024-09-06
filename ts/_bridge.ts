
export const importZigFunctions = (exports: WebAssembly.Exports) => ({
	_onFrameRequest: exports.a as any,
	_onPointerEvent: exports.b as any,
	_onKeyboardEvent: exports.c as any,
    _memory: exports.memory as WebAssembly.Memory,
});

export type ExportMap = {
	_drawTriangles: Function,
	_playUserAudioBuffer: Function,
	_setupPass: Function,
	_sin: Function,
	_cos: Function,
	_pow: Function,
	_atan2: Function,
	_text: Function,
};

export const createExportMap = ({
	_drawTriangles,
	_playUserAudioBuffer,
	_setupPass,
	_sin,
	_cos,
	_pow,
	_atan2,
	_text,
}: ExportMap) => ({
    "0": {
		a: _drawTriangles,
		b: _playUserAudioBuffer,
		c: _setupPass,
		d: _sin,
		e: _cos,
		f: _pow,
		g: _atan2,
		h: _text,
    },
});
