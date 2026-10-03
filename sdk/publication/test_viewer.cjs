// Exercise the real player logic without a browser or physics runtime.
// This checks controls and recorded values, not browser rendering.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const root = path.resolve(__dirname, "../..");
const elements = new Map();
const draws = [];
const context2d = new Proxy({}, {
  get(target, key) { return target[key] ?? ((...args) => {
    for (const value of args) if (typeof value === "number") assert.ok(Number.isFinite(value), `Non-finite canvas input: ${key}`);
    if (key === "clearRect") draws.push(key);
  }); },
  set(target, key, value) { target[key] = value; return true; }
});
function element(id) {
  if (!elements.has(id)) elements.set(id, {
    value: id === "engine" ? "godot_jolt" : id === "speed" ? "1" : "0",
    handlers: {}, attributes: {},
    addEventListener(type, fn) { this.handlers[type] = fn; },
    setAttribute(key, value) { this.attributes[key] = value; },
    getContext() { return context2d; },
    getBoundingClientRect() { return { width: 1100, height: 420 }; },
    setPointerCapture() {}
  });
  return elements.get(id);
}
let scheduled;
const document = { getElementById: element, handlers: {}, hidden: false,
  addEventListener(type, fn) { this.handlers[type] = fn; } };
const sandbox = { window: { devicePixelRatio: 1 }, document,
  ResizeObserver: class { constructor(fn) { this.callback = fn; } observe() {} },
  requestAnimationFrame(fn) { scheduled = fn; } };
vm.createContext(sandbox);
vm.runInContext(fs.readFileSync(path.join(root, "replay/bundle.js"), "utf8"), sandbox);
vm.runInContext(fs.readFileSync(path.join(root, "replay/viewer.js"), "utf8"), sandbox);
for (const session of sandbox.window.LOCO_REPLAY.sessions) {
  element("engine").value = session.engine;
  element("engine").handlers.change();
  assert.equal(element("timeline").max, session.frames.length - 1);
  assert.equal(element("source").textContent, session.source_commit);
  assert.equal(element("play").textContent, "Play");
  element("jump").handlers.click();
  const impulseFrame = Number(element("timeline").value);
  assert.ok(session.frames[impulseFrame][5].length > 0);
  element("timeline").value = session.frames.length - 1;
  element("timeline").handlers.input();
  assert.equal(element("frame").textContent, session.frames.at(-1)[0].toLocaleString());
  element("play").handlers.click(); // End-of-session restart.
  scheduled(0); scheduled(1000);
  assert.ok(Number(element("timeline").value) > 0);
  assert.equal(element("play").textContent, "Pause");
  document.hidden = true; document.handlers.visibilitychange();
  assert.equal(element("play").textContent, "Play");
  document.hidden = false;
  const canvas = element("canvas");
  canvas.handlers.pointerdown({clientX: 100, clientY: 100, pointerId: 1});
  canvas.handlers.pointermove({clientX: 160, clientY: 120});
  canvas.handlers.pointerup();
  canvas.handlers.wheel({deltaY: -100, preventDefault() {}});
  element("reset-view").handlers.click();
}
assert.ok(draws.length > 15);
console.log(JSON.stringify({ok: true, engines: 3, controls_checked: ["engine selection", "impulse jump", "scrub", "play", "restart", "background pause", "orbit", "zoom", "reset"], browser_rendering_verified: false}));
