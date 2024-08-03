import { MEM } from "./mem";

export const audioContext = new AudioContext();

export const audioMaster = audioContext.createGain();
audioMaster.connect(audioContext.destination);

export const snd: AudioBuffer[] = [];

export const play = (
    idx: number,
    vol: number | StereoPannerNode,
    pan: number | AudioBufferSourceNode,
    gain?: GainNode,
): void => {
    gain = audioContext.createGain();
    gain.gain.value = vol as number;
    gain.connect(audioMaster);

    vol = audioContext.createStereoPanner();
    vol.pan.value = pan as number;
    vol.connect(gain);

    pan = audioContext.createBufferSource();
    pan.buffer = snd[idx];
    pan.connect(vol);
    pan.start();
};

export const playNote = (idx:number, note: number, when: number, len: number, audioSource = audioContext.createBufferSource()) => {
    audioSource.buffer = snd[idx];
    audioSource.detune.value = note * 100; //2 ** ((note - 12) / 12);
    audioSource.connect(audioMaster);
    audioSource.start(when, 0, len);
}

export const createSound = (ptrData: number, samples: number, audioBuffer = audioContext.createBuffer(1, samples, 44100)) => {
    audioBuffer.getChannelData(0).set(new Float32Array(MEM.buffer, ptrData, samples));
    snd.push(audioBuffer);
};

export const playUserAudioBuffer = (ptrSamples: Ptr<f32>, length: u32) => {
    const buffer = audioContext.createBuffer(1, length, 44100);
    buffer.getChannelData(0).set(new Float32Array(MEM.buffer, ptrSamples, length));
    const gain = audioContext.createGain();
    gain.gain.value = 1.0;
    gain.connect(audioMaster);

    const pan = audioContext.createStereoPanner();
    pan.pan.value = 0.0;
    pan.connect(gain);

    const source = audioContext.createBufferSource();
    source.buffer = buffer;
    source.connect(pan);
    source.start();
};

export const unlockAudio = () => {
    if (audioContext.state[0] == "s") {
        audioContext.resume().catch();
    }
};
