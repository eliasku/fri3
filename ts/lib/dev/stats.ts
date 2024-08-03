let verticesTotal = 0;
let indicesTotal = 0;
let verticesMax = 0;
let indicesMax = 0;
let handleMax = 0;
let handleCur = 0;
let dc = 0;
let prevTime = 0;
let frames = 0;
let fps = 0;

export const addRenderStats = (vertices: number, indices: number, handle: number) => {
    verticesTotal += vertices;
    indicesTotal += indices;
    handleCur = handle;
    if (verticesMax < vertices) {
        verticesMax = vertices;
    }
    if (indicesMax < indices) {
        indicesMax = indices;
    }
    if (handleMax < handle) {
        handleMax = handle;
    }
    ++dc;
};

let fpsCanvas: HTMLCanvasElement;
let fpsContext: CanvasRenderingContext2D;
let info: HTMLParagraphElement;

export const addStatsView = () => {
    info = document.createElement("div");
    info.id = "info";
    document.body.appendChild(info);
    info.style.position = "absolute";
    info.style.left = "10px";
    info.style.top = "10px";
    info.style.width = "200px";
    info.style.height = "50px";
    info.style.zIndex = "10";
    info.style.color = "white";
    info.style.fontStyle = "bold";
    info.style.fontFamily = "monospace";
    info.style.textShadow = "#000 1px 1px 0";
    info.style.pointerEvents = "none";

    fpsCanvas = document.createElement("canvas");
    document.body.appendChild(fpsCanvas);
    fpsCanvas.id = "fps";
    fpsCanvas.width = 200;
    fpsCanvas.height = 80;
    fpsCanvas.style.width = ((fpsCanvas.width / devicePixelRatio) | 0) + "px";
    fpsCanvas.style.height = ((fpsCanvas.height / devicePixelRatio) | 0) + "px";
    fpsCanvas.style.position = "absolute";
    fpsCanvas.style.left = "10px";
    fpsCanvas.style.top = "10px";
    fpsCanvas.style.zIndex = "0";
    fpsCanvas.style.pointerEvents = "none";
    fpsContext = fpsCanvas.getContext("2d")!;
    fpsContext.fillStyle = "#333";
    fpsContext.fillRect(0, 0, fpsCanvas.width, fpsCanvas.height);
};

export const updateStatsText = (t: number) => {
    const q = 10;
    const interval = 1000 / q;
    ++frames;
    if (t - prevTime >= interval) {
        while (t - prevTime >= interval) {
            prevTime += interval;
        }
        fps = frames * q;
        frames = 0;

        fpsContext.drawImage(fpsCanvas, -1, 0);
        fpsContext.fillStyle = "#333";
        fpsContext.fillRect(fpsCanvas.width - 1, 0, 1, fpsCanvas.height);
        fpsContext.fillStyle = "#375";
        fpsContext.fillRect(fpsCanvas.width - 1, fpsCanvas.height - fps, 1, fps);
    }

    document.getElementById("info")!.innerText = `FPS ${fps}\nv ${verticesTotal} / max: ${verticesMax}\ni ${indicesTotal} / max ${indicesMax}\ndc: ${dc}\nbuffers: ${handleCur} / max ${handleMax}`;
    verticesTotal = indicesTotal = dc = 0;
    //verticesMax = indicesMax = 0;
};