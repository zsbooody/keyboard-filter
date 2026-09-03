#!/usr/bin/env python3
"""Call MiniMax H3 via AutoDL.Art (same path as Storyloom). Token from ~/.storyloom/config.json."""
from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "media" / "h3"
REFS = OUT / "refs"
CFG = Path.home() / ".storyloom" / "config.json"
BASE = "https://autodl.art"
WORKFLOW_10S = "minimax_h3_lightx2v_v5"
WORKFLOW_15S = "minimax_h3_lightx2v_v5_15s"


def token() -> str:
    data = json.loads(CFG.read_text())
    key = str(data.get("autodlKey") or "").strip()
    if not key:
        raise SystemExit("no autodlKey in ~/.storyloom/config.json")
    return key


def to_data_url(path: Path, max_side: int = 1920, quality: int = 84) -> str:
    im = Image.open(path).convert("RGB")
    w, h = im.size
    scale = min(1.0, max_side / max(w, h))
    if scale < 1:
        im = im.resize((int(w * scale), int(h * scale)), Image.Resampling.LANCZOS)
    import io

    buf = io.BytesIO()
    im.save(buf, format="JPEG", quality=quality, optimize=True)
    import base64

    b64 = base64.b64encode(buf.getvalue()).decode("ascii")
    return f"data:image/jpeg;base64,{b64}"


def api(path: str, key: str, payload: dict | None = None, timeout: int = 60) -> dict:
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(
        f"{BASE}{path}",
        data=data,
        method="POST" if payload is not None else "GET",
        headers={
            "accept": "application/json",
            "authorization": key,
            **({"content-type": "application/json"} if payload is not None else {}),
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            body = r.read().decode()
    except urllib.error.HTTPError as e:
        err = e.read().decode(errors="replace")[:800]
        raise SystemExit(f"HTTP {e.code} {path}: {err}") from e
    return json.loads(body) if body else {}


def find_str(obj, keys: set[str]):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k in keys and isinstance(v, str) and v.strip():
                return v.strip()
            found = find_str(v, keys)
            if found:
                return found
    elif isinstance(obj, list):
        for it in obj:
            found = find_str(it, keys)
            if found:
                return found
    return None


def find_url(obj):
    if isinstance(obj, str) and obj.startswith("http"):
        return obj
    if isinstance(obj, dict):
        for v in obj.values():
            u = find_url(v)
            if u:
                return u
    if isinstance(obj, list):
        for it in obj:
            u = find_url(it)
            if u:
                return u
    return None


def submit(key: str, prompt: str, images: list[Path], duration: int, resolution: str, workflow: str) -> str:
    body: dict = {
        "prompt": prompt,
        "duration": duration,
        "resolution": resolution,
    }
    for i, p in enumerate(images):
        body[f"ref_image_{i}"] = to_data_url(p)
        print(f"  ref_image_{i}: {p.name}", flush=True)
    print(f"submit {workflow} {duration}s {resolution}", flush=True)
    payload = api(f"/api/v1/comfyui/comfyui_workflow/{workflow}", key, body, timeout=90)
    tid = find_str(payload, {"task_id", "taskId", "id", "job_id", "jobId"})
    if not tid:
        raise SystemExit(f"no task id in response: {json.dumps(payload)[:500]}")
    print(f"task {tid}", flush=True)
    return tid


def poll(key: str, task_id: str, dest: Path) -> Path:
    t0 = time.time()
    while time.time() - t0 < 1800:
        payload = api(f"/api/v1/comfyui/comfyui_workflow/result/{task_id}", key, timeout=45)
        status = (find_str(payload, {"status", "state"}) or "").lower()
        url = find_url(payload)
        elapsed = int(time.time() - t0)
        print(f"  [{elapsed:4d}s] status={status or 'pending'}", flush=True)
        if url:
            print(f"  downloading {url[:80]}...", flush=True)
            req = urllib.request.Request(url, headers={"authorization": key})
            with urllib.request.urlopen(req, timeout=120) as r:
                dest.write_bytes(r.read())
            print(f"  wrote {dest} ({dest.stat().st_size} bytes)", flush=True)
            return dest
        if status in {"failed", "error", "canceled", "cancelled", "rejected"}:
            raise SystemExit(f"task failed: {json.dumps(payload)[:600]}")
        time.sleep(8)
    raise SystemExit("timeout 1800s")


SHOTS = [
    {
        "id": "01_open",
        "images": ["title.jpg", "compare.jpg"],
        "duration": 10,
        "resolution": "1080p横",
        "workflow": WORKFLOW_10S,
        "prompt": """Cinematic dark luxury product film, 16:9, matching the reference frames exactly.

Start on <Picture 1>: a black void with a faint blue grid and two soft light orbs. The Keyboard Filter wordmark sits in the center under a rounded K mark. Slow, expensive camera push-in. The glow breathes once.

At mid-shot the composition dissolves into <Picture 2>: two glass cards. Left card labeled 未过滤, the A keycap presses once and a red ghost letter A appears beside the white A. Right card labeled 已过滤, the A keycap presses once and only a single white A remains, the keycap lighting blue.

Keep all on-screen Chinese and English text sharp and unchanged. No people, no extra logos, no glitch, no particle explosion.

overall_soundscape: One clean mechanical key click on the press, then a muted digital tick when the extra letter is blocked. No speech.
non_diegetic_music: Low dark ambient electronic pad, restrained, modern.""",
    },
    {
        "id": "02_product",
        "images": ["mech.jpg", "product.jpg"],
        "duration": 10,
        "resolution": "1080p横",
        "workflow": WORKFLOW_10S,
        "prompt": """Cinematic dark product film, 16:9, locked to the reference frames.

Open on <Picture 1>: three stacked specification lines about a system keyboard hook, 35ms bounce learning, and 180ms key-repeat pass-through. Slow downward camera drift as each line brightens in order.

Then the frame becomes <Picture 2>: two floating device windows on the dark grid — a macOS menu for Keyboard Filter on the left, a dark advanced-settings keyboard board on the right with F3 and 3 keys lit blue. Gentle parallax, no UI text rewriting.

Keep typography exact. No humans. No extra interface.

overall_soundscape: Soft UI whoosh on the transition, faint keyboard clicks inside the settings window. No speech.
non_diegetic_music: Continue the same low ambient pad.""",
    },
    {
        "id": "03_close",
        "images": ["modes.jpg", "end.jpg"],
        "duration": 10,
        "resolution": "1080p横",
        "workflow": WORKFLOW_10S,
        "prompt": """Cinematic dark product film, 16:9, matching the references.

Begin on <Picture 1>: three mode cards — 全盘, 手动选键, 自动分析 — sliding into place above four stat tiles (35ms, 180ms, 10 per second, 300KB). Slow push-in.

Dissolve to <Picture 2>: the Keyboard Filter end card, K mark, wordmark, and the line 开源 · 轻量 · 系统级过滤. Hold, then a last tiny push-in.

Do not invent new words. No people. No glitch.

overall_soundscape: A small resolved chime at the end card. No speech.
non_diegetic_music: Ambient pad swells slightly then fades.""",
    },
]


def prepare_refs() -> None:
    REFS.mkdir(parents=True, exist_ok=True)
    mapping = {
        "title.jpg": Path("/tmp/kf-full/f_title.png"),
        "compare.jpg": Path("/tmp/kf-full/f_cmp.png"),
        "mech.jpg": Path("/tmp/kf-full/f_mech.png"),
        "product.jpg": Path("/tmp/kf-full/f_prod.png"),
        "modes.jpg": Path("/tmp/kf-full/f_modes.png"),
        "end.jpg": Path("/tmp/kf-full/f_end.png"),
    }
    for name, src in mapping.items():
        dest = REFS / name
        im = Image.open(src).convert("RGB")
        im.save(dest, "JPEG", quality=90, optimize=True)
        print("ref", dest, dest.stat().st_size)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--shot", default="all")
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    prepare_refs()
    if args.prepare_only:
        return
    key = token()
    shots = SHOTS if args.shot == "all" else [s for s in SHOTS if s["id"] == args.shot]
    if not shots:
        raise SystemExit(f"unknown shot {args.shot}")
    for shot in shots:
        dest = OUT / f"{shot['id']}.mp4"
        images = [REFS / n for n in shot["images"]]
        tid = submit(key, shot["prompt"], images, shot["duration"], shot["resolution"], shot["workflow"])
        (OUT / f"{shot['id']}.json").write_text(json.dumps({"task": tid, **{k: shot[k] for k in ('id','duration','resolution','workflow')}}, ensure_ascii=False, indent=2))
        poll(key, tid, dest)


if __name__ == "__main__":
    main()
