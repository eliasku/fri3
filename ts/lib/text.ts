import { getDevicePixelRatio as getDPR } from "./base/canvas";
const ox = x;
const create = (): HTMLDivElement => ox.cloneNode(true) as HTMLDivElement;

const pool: HTMLDivElement[] = [];

export const text = (id: i32, x: i32, y: i32, color: u32, size: f32, text: string, _s = (1 / getDPR()), _el = pool[id] || create(), _child = _el.children[0] as HTMLDivElement) => {
    if (!_el.parentNode) {
        pool[id] = _el;
        b.append(_el);
    }
    _el.style.left = `${x * _s}px`;
    _el.style.top = `${y * _s}px`;
    _el.style.font = `${size}vmin monospace`;
    _el.style.color = `#${color.toString(16).padStart(6, "0")}`
    _child.innerText = text;
};

