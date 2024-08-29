import { unlockAudio } from "./audio";
import { getDevicePixelRatio as getDPR } from "./canvas";

export type PointerCallback = (
    id: u32,
    isPrimary: u32,
    buttons: u32,
    event: PointerEventType,
    type: u32,
    x: f32,
    y: f32,
) => void;

export const PointerEventType = {
    DOWN: 0,
    MOVE: 1,
    UP: 2,
    ENTER: 3,
    LEAVE: 4,
} as const;

export type PointerEventType = (typeof PointerEventType)[keyof typeof PointerEventType];

export const KeyboardEventType = {
    DOWN: 0,
    UP: 1,
} as const;

export type KeyboardEventType = (typeof KeyboardEventType)[keyof typeof KeyboardEventType];

export type KeyboardCallback = (
    event: KeyboardEventType,
    code: u32,
) => void;

export const setupInput = (pointerCallback: PointerCallback, keyboardCallback: KeyboardCallback) => {

    const pointerTypeMap = {
        mouse: 0,
        touch: 1,
        pen: 2,
    };

    const _handlePointer = (e: PointerEvent, event: PointerEventType,
        _bb: DOMRect = c.getBoundingClientRect(), _s = getDPR()) => {
        pointerCallback(
            e.pointerId,
            e.isPrimary ? 1 : 0,
            e.buttons,
            event,
            pointerTypeMap[e.pointerType],
            (e.clientX - _bb.x + e.width / 2) * _s,
            (e.clientY - _bb.y + e.height / 2) * _s,
        );
    };

    c.onpointerdown = (e: PointerEvent) => _handlePointer(e, PointerEventType.DOWN);
    c.onpointermove = (e: PointerEvent) => _handlePointer(e, PointerEventType.MOVE);
    c.onpointerup = (e: PointerEvent) => {
        unlockAudio();
        _handlePointer(e, PointerEventType.UP);
    }
    c.onpointerenter = (e: PointerEvent) => _handlePointer(e, PointerEventType.ENTER);
    c.onpointerleave = (e: PointerEvent) => _handlePointer(e, PointerEventType.LEAVE);

    // disable pinch-zoom from macbook touchpad
    addEventListener("wheel", e => {
        e.preventDefault();

        // pitch-zoom gesture
        //if (e.ctrlKey) {
        //console.log("onwheel, ctrl: " + e.ctrlKey);
        //}
    }, { passive: false });

    //oncontextmenu = e => e.preventDefault();

    /*document.*/
    onkeydown = (e: KeyboardEvent, _code = e.keyCode) => {
        unlockAudio();
        // if (isModalPopupActive) {
        //     return handleModalKeyEvent(e);
        // } else {
        if (!e.repeat && _code) {
            keyboardCallback(KeyboardEventType.DOWN, _code);
        }
        // iframe parent received game key events #220
        //if (_kode >= 37 && _kode <= 40) {
        e.preventDefault();
        return false;
        //}
        // }
    };
    /*document.*/
    onkeyup = (e: KeyboardEvent, _code = e.keyCode) => {
        e.preventDefault();
        if (_code) {
            keyboardCallback(KeyboardEventType.UP, _code);
        }
    };
};

// const resetPointer = (p: Pointer) => (p._downEvent = p._upEvent = false);

// export const clearInput = () => {
//     keyboardDown.length = 0;
//     keyboardUp.length = 0;
// };