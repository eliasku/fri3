import { getDevicePixelRatio as getDPR } from "./base/canvas";
const ox = x;
const create = (): HTMLDivElement => ox.cloneNode(true) as HTMLDivElement;

const pool: HTMLDivElement[] = [];

export const text = (id: i32, x: i32, y: i32, color: u32, size: f32, text: string, _s = (1 / getDPR()), _el = pool[id]) => {
    if (!_el) {
        if (!text) return;
        _el = create();
        pool[id] = _el;
        b.append(_el);
    }
    _el.style.left = `${x * _s}px`;
    _el.style.top = `${y * _s}px`;
    _el.style.font = `${size}vmin monospace`;
    _el.style.color = `#${color.toString(16).padStart(6, "0")}`
    //_el.style.textAlign = "center";
    _el.style.zIndex = "1" + y;
    (_el.children[0] as HTMLDivElement).innerText = text;
};

