
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
	_log: Function,
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
	_log,
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
		d: _log,
		e: _sin,
		f: _cos,
		g: _pow,
		h: _atan2,
		i: _text,
    },
});
