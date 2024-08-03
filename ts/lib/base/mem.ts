export let MEM: WebAssembly.Memory;
export let U8 = new Uint8Array();
export let U32 = new Uint32Array();

export const checkMemory = (buffer = MEM.buffer) => {
    if (buffer !== U8.buffer) {
        U8 = new Uint8Array(buffer);
        U32 = new Uint32Array(buffer);
    }
};

export const initMemoryObjects = (memory: WebAssembly.Memory) => {
    MEM = memory;
};

const decoder = new TextDecoder();
export const decodeText = (ptr: Ptr<u8>, len: usize): string => decoder.decode(new Uint8Array(MEM.buffer, ptr, len));
