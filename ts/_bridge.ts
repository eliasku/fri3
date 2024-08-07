
export const importZigFunctions = (exports: WebAssembly.Exports) => ({
	_onFrameRequest: exports.a as any,
	_onPointerEvent: exports.b as any,
	_onKeyboardEvent: exports.c as any,
    _memory: exports.memory as WebAssembly.Memory,
});

export type ExportMap = {
	_drawTriangles: Function,
	_playUserAudioBuffer: Function,
	_setTexture: Function,
	_setTextureData: Function,
	_setupPass: Function,
	_log: Function,
	_drawText: Function,
	_sin: Function,
	_cos: Function,
	_pow: Function,
	_atan2: Function,
};

export const createExportMap = ({
	_drawTriangles,
	_playUserAudioBuffer,
	_setTexture,
	_setTextureData,
	_setupPass,
	_log,
	_drawText,
	_sin,
	_cos,
	_pow,
	_atan2,
}: ExportMap) => ({
    "0": {
		a: _drawTriangles,
		b: _playUserAudioBuffer,
		c: _setTexture,
		d: _setTextureData,
		e: _setupPass,
		f: _log,
		g: _drawText,
		h: _sin,
		i: _cos,
		j: _pow,
		k: _atan2,
    },
});
