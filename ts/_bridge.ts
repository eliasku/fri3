
export const importZigFunctions = (exports: WebAssembly.Exports) => ({
	_onSetup: exports.a as any,
	_onFirstFrame: exports.b as any,
	_onFrame: exports.c as any,
	_onPointerEvent: exports.d as any,
	_onKeyboardEvent: exports.e as any,
    _memory: exports.memory as WebAssembly.Memory,
});

export type ExportMap = {
	_drawTriangles: Function,
	_playUserAudioBuffer: Function,
	_setTexture: Function,
	_setTextureData: Function,
	_setupPass: Function,
	_log: Function,
	_createFont: Function,
	_getFontStatus: Function,
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
	_createFont,
	_getFontStatus,
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
		g: _createFont,
		h: _getFontStatus,
		i: _drawText,
		j: _sin,
		k: _cos,
		l: _pow,
		m: _atan2,
    },
});
