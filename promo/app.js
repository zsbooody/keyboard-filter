(() => {
  const ROWS = {
    fn: [["Esc", 53, 1], ["F1", 122, 1], ["F2", 120, 1], ["F3", 99, 1], ["F4", 118, 1], ["F5", 96, 1], ["F6", 97, 1], ["F7", 98, 1], ["F8", 100, 1], ["F9", 101, 1], ["F10", 109, 1], ["F11", 103, 1], ["F12", 111, 1]],
    num: [["`", 50, 1], ["1", 18, 1], ["2", 19, 1], ["3", 20, 1], ["4", 21, 1], ["5", 23, 1], ["6", 22, 1], ["7", 26, 1], ["8", 28, 1], ["9", 25, 1], ["0", 29, 1], ["-", 27, 1], ["=", 24, 1], ["Delete", 51, 1.6]],
    tab: [["Tab", 48, 1.5], ["Q", 12, 1], ["W", 13, 1], ["E", 14, 1], ["R", 15, 1], ["T", 17, 1], ["Y", 16, 1], ["U", 32, 1], ["I", 34, 1], ["O", 31, 1], ["P", 35, 1], ["[", 33, 1], ["]", 30, 1], ["\\", 42, 1.5]],
    caps: [["Caps", 57, 1.75], ["A", 0, 1], ["S", 1, 1], ["D", 2, 1], ["F", 3, 1], ["G", 5, 1], ["H", 4, 1], ["J", 38, 1], ["K", 40, 1], ["L", 37, 1], [";", 41, 1], ["'", 39, 1], ["Return", 36, 1.85]],
    shift: [["Shift", 56, 2.25], ["Z", 6, 1], ["X", 7, 1], ["C", 8, 1], ["V", 9, 1], ["B", 11, 1], ["N", 45, 1], ["M", 46, 1], [",", 43, 1], [".", 47, 1], ["/", 44, 1], ["Shift", 60, 2.35]],
    bot: [["Ctrl", 59, 1.25], ["Opt", 58, 1.25], ["Cmd", 55, 1.35], ["Space", 49, 5.5], ["Cmd", 54, 1.35], ["Opt", 61, 1.25], ["Ctrl", 62, 1.25]]
  };
  const NAV = {
    top: [["Del", 117, 1], ["Home", 115, 1], ["PgUp", 116, 1]],
    mid: [["End", 119, 1], ["PgDn", 121, 1]],
    up: [["↑", 126, 1]],
    arrows: [["←", 123, 1], ["↓", 125, 1], ["→", 124, 1]]
  };
  const CODE_MAP = {
    Escape: [53, "Esc"], Digit1: [18, "1"], Digit2: [19, "2"], Digit3: [20, "3"], Digit4: [21, "4"], Digit5: [23, "5"], Digit6: [22, "6"], Digit7: [26, "7"], Digit8: [28, "8"], Digit9: [25, "9"], Digit0: [29, "0"], Minus: [27, "-"], Equal: [24, "="], Backspace: [51, "⌫"], Tab: [48, "⇥"], KeyQ: [12, "Q"], KeyW: [13, "W"], KeyE: [14, "E"], KeyR: [15, "R"], KeyT: [17, "T"], KeyY: [16, "Y"], KeyU: [32, "U"], KeyI: [34, "I"], KeyO: [31, "O"], KeyP: [35, "P"], BracketLeft: [33, "["], BracketRight: [30, "]"], Backslash: [42, "\\"], KeyA: [0, "A"], KeyS: [1, "S"], KeyD: [2, "D"], KeyF: [3, "F"], KeyG: [5, "G"], KeyH: [4, "H"], KeyJ: [38, "J"], KeyK: [40, "K"], KeyL: [37, "L"], Semicolon: [41, ";"], Quote: [39, "'"], Enter: [36, "⏎"], KeyZ: [6, "Z"], KeyX: [7, "X"], KeyC: [8, "C"], KeyV: [9, "V"], KeyB: [11, "B"], KeyN: [45, "N"], KeyM: [46, "M"], Comma: [43, ","], Period: [47, "."], Slash: [44, "/"], Space: [49, " "], Backquote: [50, "`"], ArrowUp: [126, "↑"], ArrowDown: [125, "↓"], ArrowLeft: [123, "←"], ArrowRight: [124, "→"]
  };

  const SCENES = {
    title: [0.0, 0.13, { holdIn: true }],
    compare: [0.10, 0.30],
    mech: [0.28, 0.44],
    product: [0.42, 0.56],
    play: [0.54, 0.74],
    modes: [0.72, 0.86],
    end: [0.84, 1.0, { holdOut: true }]
  };
  const SUBS = [
    [0.02, 0.11, "Keyboard Filter。"],
    [0.13, 0.26, "你按一次，它有时会记两次。"],
    [0.30, 0.42, "钩子在系统入口。只拦回弹，不拦连发。"],
    [0.44, 0.54, "菜单栏里，画板上点选。"],
    [0.74, 0.84, "三种模式。默认十次每秒。"],
    [0.86, 0.98, "开源，轻量，系统级过滤。"]
  ];

  const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const bar = document.getElementById("bar");
  const subEl = document.getElementById("sub");
  const hint = document.getElementById("scrollHint");
  const nodes = {};
  document.querySelectorAll(".scene").forEach((el) => { nodes[el.dataset.scene] = el; });

  function clamp(x, a, b) { return Math.max(a, Math.min(b, x)); }
  function smooth(t) {
    t = clamp(t, 0, 1);
    return t * t * (3 - 2 * t);
  }
  function weight(p, a, b, opt) {
    const span = Math.max(0.001, b - a);
    const fade = span * 0.22;
    const inn = opt && opt.holdIn
      ? (p >= a ? 1 : 0)
      : smooth((p - a) / fade);
    const out = opt && opt.holdOut
      ? (p <= b ? 1 : 0)
      : 1 - smooth((p - (b - fade)) / fade);
    return clamp(inn, 0, 1) * clamp(out, 0, 1);
  }
  function scrollP() {
    const max = Math.max(1, document.getElementById("spine").offsetHeight - innerHeight);
    return clamp(scrollY / max, 0, 1);
  }
  function jumpTo(p) {
    const max = Math.max(1, document.getElementById("spine").offsetHeight - innerHeight);
    scrollTo({ top: p * max, behavior: reduce ? "auto" : "smooth" });
  }

  let shown = 0;
  let compareState = "";
  let lastClickAt = -1;

  const sound = {
    ctx: null, music: null, on: false,
    ensure() {
      if (!this.ctx) this.ctx = new (window.AudioContext || window.webkitAudioContext)();
      if (this.ctx.state === "suspended") this.ctx.resume();
      if (!this.music) {
        this.music = new Audio("media/audio/music.mp3");
        this.music.loop = true;
        this.music.volume = 0.16;
      }
    },
    tone(f, d, type, g) {
      if (!this.on || !this.ctx) return;
      const o = this.ctx.createOscillator();
      const a = this.ctx.createGain();
      o.type = type; o.frequency.value = f;
      a.gain.setValueAtTime(g, this.ctx.currentTime);
      a.gain.exponentialRampToValueAtTime(0.0001, this.ctx.currentTime + d);
      o.connect(a).connect(this.ctx.destination);
      o.start(); o.stop(this.ctx.currentTime + d);
    },
    click() { this.tone(1800, 0.045, "triangle", 0.05); this.tone(88, 0.05, "sine", 0.04); },
    block() { this.tone(210, 0.09, "square", 0.03); }
  };

  function setTape(el, first, bounce) {
    const key = `${first ? 1 : 0}${bounce ? 1 : 0}`;
    if (el.dataset.k === key) return;
    el.dataset.k = key;
    el.textContent = "";
    if (!first) return;
    const a = document.createElement("span");
    a.className = "ch"; a.textContent = "A"; el.appendChild(a);
    if (bounce) {
      const b = document.createElement("span");
      b.className = "ch dup"; b.textContent = "A"; el.appendChild(b);
    }
  }

  function paintCompare(p) {
    const [a, b] = SCENES.compare;
    const lp = (p - a) / (b - a);
    const press = (lp > 0.18 && lp < 0.5) || (lp > 0.58 && lp < 0.84);
    document.getElementById("capBad").classList.toggle("down", press);
    document.getElementById("capGood").classList.toggle("down", press);
    setTape(document.getElementById("tapeBad"), lp > 0.24, lp > 0.36);
    setTape(document.getElementById("tapeGood"), lp > 0.24, false);
    const beat = lp > 0.2 && lp < 0.28 ? "a" : lp > 0.6 && lp < 0.68 ? "b" : "";
    if (beat && beat !== lastClickAt) {
      lastClickAt = beat;
      sound.click();
    }
  }

  function paintMech(p) {
    const [a, b] = SCENES.mech;
    const lp = (p - a) / (b - a);
    document.querySelectorAll(".lines li").forEach((li) => {
      const i = Number(li.dataset.line);
      li.classList.toggle("on", lp > 0.16 + i * 0.22);
    });
  }

  function paintModes(p) {
    const [a, b] = SCENES.modes;
    const lp = (p - a) / (b - a);
    document.querySelectorAll(".mode-row article").forEach((el) => {
      const i = Number(el.dataset.card);
      el.classList.toggle("on", lp > 0.12 + i * 0.16);
    });
  }

  function paintProduct(active) {
    ["vidMenu", "vidBoard"].forEach((id) => {
      const v = document.getElementById(id);
      if (!v) return;
      if (active) v.play().catch(() => {});
      else v.pause();
    });
  }

  function apply(p) {
    bar.style.width = `${p * 100}%`;
    hint.style.opacity = String(clamp(1 - p / 0.06, 0, 1));

    let line = "";
    SUBS.forEach(([a, b, s]) => { if (p >= a && p < b) line = s; });
    if (line) {
      if (subEl.textContent !== line) subEl.textContent = line;
      subEl.classList.add("show");
    } else subEl.classList.remove("show");

    Object.entries(SCENES).forEach(([name, spec]) => {
      const [a, b, opt] = spec;
      const w = reduce ? 1 : weight(p, a, b, opt);
      const el = nodes[name];
      if (!el) return;
      el.style.opacity = String(w);
      el.style.filter = reduce ? "none" : `blur(${(1 - w) * 10}px)`;
      el.style.transform = reduce ? "none" : `translate3d(0, ${(1 - w) * 28}px, 0) scale(${0.97 + 0.03 * w})`;
      el.classList.toggle("active", w > 0.42);
    });

    paintCompare(p);
    paintMech(p);
    paintModes(p);
    paintProduct(weight(p, ...SCENES.product) > 0.45);
  }

  function tick() {
    const target = scrollP();
    shown = reduce ? target : shown + (target - shown) * 0.16;
    if (Math.abs(target - shown) < 0.0004) shown = target;
    apply(shown);
    requestAnimationFrame(tick);
  }

  document.querySelectorAll("[data-jump]").forEach((el) => {
    el.addEventListener("click", (ev) => {
      ev.preventDefault();
      jumpTo(Number(el.dataset.jump));
    });
  });

  const kb = document.getElementById("keyboard");
  const rawOut = document.getElementById("rawOut");
  const fltOut = document.getElementById("fltOut");
  const statusLine = document.getElementById("statusLine");
  const bounceToggle = document.getElementById("bounceToggle");
  const filterToggle = document.getElementById("filterToggle");
  const consoleEl = document.getElementById("console");
  const lastOk = new Map();
  let demoLock = false;

  function rateMs() {
    const checked = document.querySelector('input[name="rate"]:checked');
    return 1000 / Number((checked && checked.value) || 10);
  }
  function rowEl(keys) {
    const row = document.createElement("div");
    row.className = "kb-row";
    keys.forEach(([label, code, w]) => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "key";
      btn.textContent = label;
      btn.style.setProperty("--w", String(w));
      btn.dataset.code = String(code);
      btn.addEventListener("click", () => tap(code, displayOf(label), false));
      row.appendChild(btn);
    });
    return row;
  }
  function displayOf(label) {
    if (label === "Space") return " ";
    if (label === "Return") return "⏎";
    if (label === "Delete") return "⌫";
    return label.length === 1 ? label : "";
  }
  function mount() {
    if (!kb) return;
    kb.appendChild(rowEl(ROWS.fn));
    const main = document.createElement("div");
    main.className = "kb-left";
    [ROWS.num, ROWS.tab, ROWS.caps, ROWS.shift, ROWS.bot].forEach((r) => main.appendChild(rowEl(r)));
    const nav = document.createElement("div");
    nav.className = "kb-nav";
    nav.appendChild(rowEl(NAV.top));
    nav.appendChild(rowEl(NAV.mid));
    const spacer = document.createElement("div");
    spacer.style.height = "14px";
    nav.appendChild(spacer);
    const up = rowEl(NAV.up);
    up.style.justifyContent = "center";
    nav.appendChild(up);
    nav.appendChild(rowEl(NAV.arrows));
    const body = document.createElement("div");
    body.className = "kb-main";
    body.appendChild(main);
    body.appendChild(nav);
    kb.appendChild(body);
  }
  function flash(code, cls) {
    kb.querySelectorAll(`.key[data-code="${code}"]`).forEach((el) => {
      el.classList.remove("is-ok", "is-block");
      el.classList.add(cls);
      setTimeout(() => el.classList.remove(cls), 140);
    });
  }
  function append(node, text, dup) {
    if (!text) return;
    const span = document.createElement("span");
    span.textContent = text === " " ? "·" : text;
    if (dup) span.className = "dup";
    node.appendChild(span);
    if (node.childNodes.length > 48) node.removeChild(node.firstChild);
  }
  function accept(code, text, isBounce) {
    append(rawOut, text, isBounce);
    const now = performance.now();
    const interval = rateMs();
    const prev = lastOk.get(code) || 0;
    const filtered = filterToggle.checked && now - prev < interval;
    if (!isBounce) sound.click();
    if (filtered) {
      flash(code, "is-block");
      sound.block();
      statusLine.textContent = `拦截 ${Math.round(now - prev)}ms`;
      return;
    }
    lastOk.set(code, now);
    append(fltOut, text, false);
    flash(code, "is-ok");
  }
  function tap(code, text, fromKey) {
    if (!text && fromKey) return;
    accept(code, text || "", false);
    if (bounceToggle.checked) setTimeout(() => accept(code, text || "", true), 18);
  }
  function clearOut() {
    rawOut.textContent = "";
    fltOut.textContent = "";
    lastOk.clear();
  }
  async function demoOnce() {
    if (demoLock) return;
    demoLock = true;
    const prevF = filterToggle.checked;
    clearOut();
    bounceToggle.checked = true;
    filterToggle.checked = false;
    tap(0, "A", false);
    await new Promise((r) => setTimeout(r, 700));
    filterToggle.checked = true;
    tap(0, "A", false);
    await new Promise((r) => setTimeout(r, 400));
    filterToggle.checked = prevF;
    statusLine.textContent = "左侧多出来的是回弹。";
    demoLock = false;
  }

  mount();
  document.getElementById("clearOut").addEventListener("click", clearOut);
  document.getElementById("demoOnce").addEventListener("click", demoOnce);
  consoleEl.addEventListener("keydown", (ev) => {
    const mapped = CODE_MAP[ev.code];
    if (!mapped) return;
    ev.preventDefault();
    if (ev.repeat) return;
    tap(mapped[0], mapped[1], true);
  });

  const soundBtn = document.getElementById("soundBtn");
  soundBtn.addEventListener("click", () => {
    sound.ensure();
    sound.on = !sound.on;
    soundBtn.setAttribute("aria-pressed", String(sound.on));
    soundBtn.textContent = sound.on ? "声音开" : "声音关";
    if (sound.on) sound.music.play().catch(() => {});
    else { sound.music.pause(); sound.music.currentTime = 0; }
  });

  shown = scrollP();
  apply(shown);
  requestAnimationFrame(tick);
})();
