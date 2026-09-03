(() => {
  const DURATION = 33.6;
  const scenes = {
    title: [0.0, 4.2],
    compare: [4.0, 11.25],
    mech: [11.05, 17.35],
    product: [17.15, 24.25],
    modes: [24.05, 28.95],
    end: [28.75, 33.7]
  };
  const subs = [
    [0.55, 2.5, "Keyboard Filter。"],
    [4.55, 8.3, "你按一次，它有时会记两次。"],
    [11.4, 16.9, "钩子在系统入口。只拦回弹，不拦连发。"],
    [24.3, 28.3, "三种模式。默认十次每秒。"],
    [28.95, 33.2, "开源，轻量，系统级过滤。"]
  ];

  const bar = document.getElementById("bar");
  const subEl = document.getElementById("sub");
  const nodes = {};
  document.querySelectorAll(".scene").forEach((el) => {
    nodes[el.dataset.scene] = el;
  });

  let start = 0;
  let compareArmed = false;
  let mechArmed = false;
  let modeArmed = false;
  let videosArmed = false;

  function setScene(name, on) {
    const el = nodes[name];
    if (!el) return;
    if (on) {
      el.classList.add("on");
      el.classList.remove("off");
    } else if (el.classList.contains("on")) {
      el.classList.remove("on");
      el.classList.add("off");
    }
  }

  function press(el, down) {
    el.classList.toggle("down", down);
  }

  function addCh(tape, text, dup) {
    const s = document.createElement("span");
    s.className = dup ? "ch dup" : "ch";
    s.textContent = text;
    tape.appendChild(s);
  }

  function runCompareBurst() {
    const capB = document.getElementById("capBad");
    const capG = document.getElementById("capGood");
    const tapeB = document.getElementById("tapeBad");
    const tapeG = document.getElementById("tapeGood");
    tapeB.textContent = "";
    tapeG.textContent = "";
    press(capB, true);
    press(capG, true);
    setTimeout(() => addCh(tapeB, "A", false), 40);
    setTimeout(() => addCh(tapeG, "A", false), 40);
    setTimeout(() => addCh(tapeB, "A", true), 160);
    setTimeout(() => {
      press(capB, false);
      press(capG, false);
    }, 180);
  }

  function tick(now) {
    const t = (now - start) / 1000;
    const p = Math.max(0, Math.min(1, t / DURATION));
    bar.style.width = p * 100 + "%";

    Object.entries(scenes).forEach(([name, [a, b]]) => {
      setScene(name, t >= a && t < b);
    });

    let line = "";
    subs.forEach(([a, b, s]) => {
      if (t >= a && t < b) line = s;
    });
    if (line) {
      if (subEl.textContent !== line) subEl.textContent = line;
      subEl.classList.add("show");
    } else {
      subEl.classList.remove("show");
    }

    if (t >= 5.15 && t < 5.4 && !compareArmed) {
      compareArmed = "first";
      runCompareBurst();
    }
    if (t >= 7.45 && t < 7.7 && compareArmed === "first") {
      compareArmed = "second";
      runCompareBurst();
    }

    if (t >= 11.4 && !mechArmed) {
      mechArmed = true;
      document.querySelectorAll(".lines li").forEach((li, i) => {
        setTimeout(() => li.classList.add("show"), i * 280);
      });
    }

    if (t >= 17.2 && !videosArmed) {
      videosArmed = true;
      document.querySelectorAll(".scene[data-scene='product'] video").forEach((v) => {
        v.currentTime = 0;
        v.play().catch(() => {});
      });
    }

    if (t >= 24.3 && !modeArmed) {
      modeArmed = true;
      document.querySelectorAll(".mode-row article").forEach((el, i) => {
        setTimeout(() => el.classList.add("show"), i * 160);
      });
    }

    if (t < DURATION + 0.3) requestAnimationFrame(tick);
  }

  function begin() {
    start = performance.now();
    compareArmed = false;
    mechArmed = false;
    modeArmed = false;
    videosArmed = false;
    requestAnimationFrame(tick);
  }

  if (location.search.includes("auto=0")) {
    document.body.addEventListener("click", begin, { once: true });
  } else {
    // small beat so first frame is composed before motion
    setTimeout(begin, 80);
  }
})();
