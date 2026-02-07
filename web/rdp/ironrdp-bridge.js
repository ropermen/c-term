/**
 * IronRDP Bridge for koder
 * Adapted from iron-remote-desktop (Devolutions/IronRDP)
 * Provides RDP session management via WASM + canvas rendering
 */

// Scancode mapping (US keyboard layout)
const SCANCODES = {
  'Escape': 0x0001, 'Digit1': 0x0002, 'Digit2': 0x0003, 'Digit3': 0x0004,
  'Digit4': 0x0005, 'Digit5': 0x0006, 'Digit6': 0x0007, 'Digit7': 0x0008,
  'Digit8': 0x0009, 'Digit9': 0x000A, 'Digit0': 0x000B, 'Minus': 0x000C,
  'Equal': 0x000D, 'Backspace': 0x000E, 'Tab': 0x000F, 'KeyQ': 0x0010,
  'KeyW': 0x0011, 'KeyE': 0x0012, 'KeyR': 0x0013, 'KeyT': 0x0014,
  'KeyY': 0x0015, 'KeyU': 0x0016, 'KeyI': 0x0017, 'KeyO': 0x0018,
  'KeyP': 0x0019, 'BracketLeft': 0x001A, 'BracketRight': 0x001B,
  'Enter': 0x001C, 'ControlLeft': 0x001D, 'KeyA': 0x001E, 'KeyS': 0x001F,
  'KeyD': 0x0020, 'KeyF': 0x0021, 'KeyG': 0x0022, 'KeyH': 0x0023,
  'KeyJ': 0x0024, 'KeyK': 0x0025, 'KeyL': 0x0026, 'Semicolon': 0x0027,
  'Quote': 0x0028, 'Backquote': 0x0029, 'ShiftLeft': 0x002A,
  'Backslash': 0x002B, 'KeyZ': 0x002C, 'KeyX': 0x002D, 'KeyC': 0x002E,
  'KeyV': 0x002F, 'KeyB': 0x0030, 'KeyN': 0x0031, 'KeyM': 0x0032,
  'Comma': 0x0033, 'Period': 0x0034, 'Slash': 0x0035, 'ShiftRight': 0x0036,
  'NumpadMultiply': 0x0037, 'AltLeft': 0x0038, 'Space': 0x0039,
  'CapsLock': 0x003A, 'F1': 0x003B, 'F2': 0x003C, 'F3': 0x003D,
  'F4': 0x003E, 'F5': 0x003F, 'F6': 0x0040, 'F7': 0x0041, 'F8': 0x0042,
  'F9': 0x0043, 'F10': 0x0044, 'NumLock': 0x0045, 'ScrollLock': 0x0046,
  'Numpad7': 0x0047, 'Numpad8': 0x0048, 'Numpad9': 0x0049,
  'NumpadSubtract': 0x004A, 'Numpad4': 0x004B, 'Numpad5': 0x004C,
  'Numpad6': 0x004D, 'NumpadAdd': 0x004E, 'Numpad1': 0x004F,
  'Numpad2': 0x0050, 'Numpad3': 0x0051, 'Numpad0': 0x0052,
  'NumpadDecimal': 0x0053, 'IntlBackslash': 0x0056, 'F11': 0x0057,
  'F12': 0x0058, 'NumpadEnter': 0xE01C, 'ControlRight': 0xE01D,
  'NumpadDivide': 0xE035, 'PrintScreen': 0xE037, 'AltRight': 0xE038,
  'Home': 0xE047, 'ArrowUp': 0xE048, 'PageUp': 0xE049,
  'ArrowLeft': 0xE04B, 'ArrowRight': 0xE04D, 'End': 0xE04F,
  'ArrowDown': 0xE050, 'PageDown': 0xE051, 'Insert': 0xE052,
  'Delete': 0xE053, 'MetaLeft': 0xE05B, 'MetaRight': 0xE05C,
  'ContextMenu': 0xE05D, 'Pause': 0xE11D,
};

class IronRdpSession {
  constructor() {
    this.wasm = null;
    this.session = null;
    this.canvas = null;
    this.active = false;
    this._onStatus = null;
    this._onError = null;
    this._onTerminate = null;
  }

  /**
   * Initialize the WASM module.
   * Must be called before connect().
   */
  async init() {
    if (this.wasm) return;

    const wasmModule = await import('./ironrdp_web.js');
    await wasmModule.default();
    wasmModule.setup('INFO');
    this.wasm = wasmModule;
  }

  /**
   * Connect to an RDP server.
   * @param {Object} opts
   * @param {string} opts.username
   * @param {string} opts.password
   * @param {string} opts.destination - host:port
   * @param {string} opts.proxyAddress - WebSocket URL to the RDCleanPath proxy
   * @param {string} [opts.domain] - Windows domain (optional)
   * @param {HTMLCanvasElement} opts.canvas - Target canvas element
   * @param {number} [opts.width=1280] - Desktop width
   * @param {number} [opts.height=720] - Desktop height
   */
  async connect(opts) {
    if (!this.wasm) {
      throw new Error('WASM module not initialized. Call init() first.');
    }

    this.canvas = opts.canvas;
    const { SessionBuilder, DesktopSize } = this.wasm;

    const desktopSize = new DesktopSize(opts.width || 1280, opts.height || 720);

    let builder = new SessionBuilder();
    builder = builder.username(opts.username);
    builder = builder.password(opts.password);
    builder = builder.destination(opts.destination);
    builder = builder.proxyAddress(opts.proxyAddress);
    builder = builder.authToken('koder');
    builder = builder.desktopSize(desktopSize);
    builder = builder.renderCanvas(opts.canvas);

    if (opts.domain) {
      builder = builder.serverDomain(opts.domain);
    }

    // Cursor style callback
    builder = builder.setCursorStyleCallback((style) => {
      if (this.canvas) {
        this.canvas.style.cursor = style || 'default';
      }
    });
    builder = builder.setCursorStyleCallbackContext(null);

    // Clipboard callbacks (optional, no-op for now)
    builder = builder.remoteClipboardChangedCallback(() => {});
    builder = builder.forceClipboardUpdateCallback(() => Promise.resolve());
    builder = builder.canvasResizedCallback(() => {});

    this._reportStatus('connecting');

    try {
      this.session = await builder.connect();
      this.active = true;
      this._reportStatus('connected');
      this._setupInputHandlers();

      // Run the session event loop (blocks until session ends)
      const termInfo = await this.session.run();
      this.active = false;
      this._reportStatus('disconnected');
      if (this._onTerminate) {
        this._onTerminate(termInfo);
      }
    } catch (e) {
      this.active = false;
      this._reportStatus('error');
      if (this._onError) {
        this._onError(e.toString());
      }
      throw e;
    }
  }

  /**
   * Send Ctrl+Alt+Del to the remote session.
   */
  ctrlAltDel() {
    if (!this.session || !this.active || !this.wasm) return;
    const { DeviceEvent, InputTransaction } = this.wasm;
    const tx = new InputTransaction();
    tx.addEvent(DeviceEvent.keyPressed(0x001D));  // Ctrl
    tx.addEvent(DeviceEvent.keyPressed(0x0038));  // Alt
    tx.addEvent(DeviceEvent.keyPressed(0xE053));  // Delete
    tx.addEvent(DeviceEvent.keyReleased(0xE053));
    tx.addEvent(DeviceEvent.keyReleased(0x0038));
    tx.addEvent(DeviceEvent.keyReleased(0x001D));
    this.session.applyInputs(tx);
  }

  /**
   * Gracefully shut down the session.
   */
  shutdown() {
    if (this.session && this.active) {
      this.session.shutdown();
      this.active = false;
    }
    this._removeInputHandlers();
  }

  /**
   * Resize the remote desktop.
   */
  resize(width, height) {
    if (this.session && this.active) {
      this.session.resize(width, height);
    }
  }

  // -- Event callbacks --

  onStatus(callback) { this._onStatus = callback; }
  onError(callback) { this._onError = callback; }
  onTerminate(callback) { this._onTerminate = callback; }

  // -- Internal --

  _reportStatus(status) {
    if (this._onStatus) this._onStatus(status);
  }

  _setupInputHandlers() {
    this._onKeyDown = (e) => this._handleKey(e, true);
    this._onKeyUp = (e) => this._handleKey(e, false);
    this._onMouseMove = (e) => this._handleMouseMove(e);
    this._onMouseDown = (e) => this._handleMouseButton(e, true);
    this._onMouseUp = (e) => this._handleMouseButton(e, false);
    this._onWheel = (e) => this._handleWheel(e);
    this._onContextMenu = (e) => e.preventDefault();

    this.canvas.addEventListener('keydown', this._onKeyDown);
    this.canvas.addEventListener('keyup', this._onKeyUp);
    this.canvas.addEventListener('mousemove', this._onMouseMove);
    this.canvas.addEventListener('mousedown', this._onMouseDown);
    this.canvas.addEventListener('mouseup', this._onMouseUp);
    this.canvas.addEventListener('wheel', this._onWheel);
    this.canvas.addEventListener('contextmenu', this._onContextMenu);

    // Make canvas focusable
    this.canvas.tabIndex = 0;
    this.canvas.focus();
  }

  _removeInputHandlers() {
    if (!this.canvas) return;
    this.canvas.removeEventListener('keydown', this._onKeyDown);
    this.canvas.removeEventListener('keyup', this._onKeyUp);
    this.canvas.removeEventListener('mousemove', this._onMouseMove);
    this.canvas.removeEventListener('mousedown', this._onMouseDown);
    this.canvas.removeEventListener('mouseup', this._onMouseUp);
    this.canvas.removeEventListener('wheel', this._onWheel);
    this.canvas.removeEventListener('contextmenu', this._onContextMenu);
  }

  _handleKey(event, isDown) {
    if (!this.session || !this.active || !this.wasm) return;
    event.preventDefault();
    event.stopPropagation();

    const scancode = SCANCODES[event.code];
    if (scancode === undefined) return;

    const { DeviceEvent, InputTransaction } = this.wasm;
    const tx = new InputTransaction();
    tx.addEvent(isDown
      ? DeviceEvent.keyPressed(scancode)
      : DeviceEvent.keyReleased(scancode));
    this.session.applyInputs(tx);
  }

  _handleMouseMove(event) {
    if (!this.session || !this.active || !this.wasm) return;

    const rect = this.canvas.getBoundingClientRect();
    const scaleX = this.canvas.width / rect.width;
    const scaleY = this.canvas.height / rect.height;
    const x = Math.round((event.clientX - rect.left) * scaleX);
    const y = Math.round((event.clientY - rect.top) * scaleY);

    const { DeviceEvent, InputTransaction } = this.wasm;
    const tx = new InputTransaction();
    tx.addEvent(DeviceEvent.mouseMove(x, y));
    this.session.applyInputs(tx);
  }

  _handleMouseButton(event, isDown) {
    if (!this.session || !this.active || !this.wasm) return;
    event.preventDefault();

    const { DeviceEvent, InputTransaction } = this.wasm;
    const tx = new InputTransaction();
    const evt = isDown
      ? DeviceEvent.mouseButtonPressed(event.button)
      : DeviceEvent.mouseButtonReleased(event.button);
    tx.addEvent(evt);
    this.session.applyInputs(tx);
  }

  _handleWheel(event) {
    if (!this.session || !this.active || !this.wasm) return;
    event.preventDefault();

    const { DeviceEvent, InputTransaction } = this.wasm;
    const tx = new InputTransaction();

    if (event.deltaY !== 0) {
      const vertical = true;
      // Normalize: positive deltaY = scroll down = negative rotation
      const rotation = event.deltaY > 0 ? -1 : 1;
      tx.addEvent(DeviceEvent.wheelRotations(vertical, rotation, 0));
    }
    if (event.deltaX !== 0) {
      const vertical = false;
      const rotation = event.deltaX > 0 ? -1 : 1;
      tx.addEvent(DeviceEvent.wheelRotations(vertical, rotation, 0));
    }

    this.session.applyInputs(tx);
  }
}

// Expose globally for Flutter JS interop
window.IronRdpSession = IronRdpSession;
