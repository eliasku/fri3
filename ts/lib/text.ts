import { getDevicePixelRatio as getDPR } from "./base/canvas";
const ox = x;
const create = ():HTMLDivElement => ox.cloneNode(true) as HTMLDivElement;

const pool: HTMLDivElement[] = [];

export const text =(id: number, x: number, y: number, text: string, _s = (1 / getDPR()), _el = pool[id] || create(), _child = _el.children[0] as HTMLDivElement) => {
    pool[id] = _el;
    b.append(_el);
    _el.style.left = `${x*_s}px`;
    _el.style.top = `${y*_s}px`;
    _child.innerText = text;
};

