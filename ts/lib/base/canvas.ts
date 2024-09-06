export const getDevicePixelRatio = () => devicePixelRatio;

setInterval((
    w: number = b.clientWidth,
    h: number = b.clientHeight,
    s: number = getDevicePixelRatio(),
) => {
    c.width = w * s;
    c.height = h * s;
    c.style.width = w + "px";
    c.style.height = h + "px";
    //c.style.imageRendering = "pixelated";
}, 200);
// resize();
// b.onresize = resize;
