#!/usr/bin/env python3
"""Sway backend helper for the Serpantinum Infinite Desktop.

The canvas engine speaks "Hyprland-shaped" JSON (monitors + clients). This helper reads the
Sway IPC and translates it, so the same engine can drive both compositors.

  sway.py snapshot   -> line 1: monitors JSON, line 2: clients JSON
  sway.py cursor     -> {"x": N, "y": N}  (Sway has no cursor query: centre of the focused output)
  sway.py move <json>-> applies [{"id":N,"x":N,"y":N,"w":N,"h":N,"float":bool}, ...] in ONE swaymsg call
"""
import json
import subprocess
import sys


def sway(*args):
    try:
        out = subprocess.run(["swaymsg", *args], capture_output=True, text=True, timeout=4)
        return out.stdout
    except Exception:
        return ""


def jget(kind):
    try:
        return json.loads(sway("-t", kind, "-r"))
    except Exception:
        return []


def snapshot():
    outputs = jget("get_outputs")
    workspaces = jget("get_workspaces")
    tree = {}
    try:
        tree = json.loads(sway("-t", "get_tree", "-r"))
    except Exception:
        tree = {}

    ws_num = {w.get("name"): w.get("num", -1) for w in workspaces}
    monitors = []
    mon_index = {}
    for i, o in enumerate(outputs):
        if not o.get("active", True):
            continue
        r = o.get("rect", {})
        cur = o.get("current_workspace")
        monitors.append({
            "id": i,
            "name": o.get("name"),
            "x": r.get("x", 0),
            "y": r.get("y", 0),
            # rect is already in logical pixels (scale and transform applied)
            "width": r.get("width", 0),
            "height": r.get("height", 0),
            "scale": 1,
            "transform": 0,
            "activeWorkspace": {"id": ws_num.get(cur, -1)},
            "focused": bool(o.get("focused")),
        })
        mon_index[o.get("name")] = i

    clients = []

    def walk(node, out_name, ws, floating):
        t = node.get("type")
        if t == "output":
            out_name = node.get("name")
        elif t == "workspace":
            ws = node
        kids = node.get("nodes", [])
        fkids = node.get("floating_nodes", [])
        is_window = bool(node.get("pid")) and not kids and t in ("con", "floating_con")
        if is_window and ws is not None:
            wr = node.get("rect", {})
            win = node.get("window_rect", {})
            num = ws.get("num", -1)
            props = node.get("window_properties") or {}
            cls = node.get("app_id") or props.get("class") or ""
            title = node.get("name") or ""
            fs = node.get("fullscreen_mode", 0)
            clients.append({
                "address": "0x%x" % node.get("id", 0),
                "mapped": True,
                "hidden": False,
                "class": cls,
                "title": title,
                "initialTitle": title,
                "workspace": {"id": num if num is not None else -1},
                "monitor": mon_index.get(out_name, 0),
                "at": [wr.get("x", 0), wr.get("y", 0)],
                # Sway's "resize set" works on the content size, so report that.
                "size": [win.get("width") or wr.get("width", 0), win.get("height") or wr.get("height", 0)],
                "floating": bool(floating or t == "floating_con"),
                "fullscreen": fs,
                "focused": bool(node.get("focused")),
            })
        for k in kids:
            walk(k, out_name, ws, floating)
        for k in fkids:
            walk(k, out_name, ws, True)

    walk(tree, None, None, False)
    sys.stdout.write(json.dumps(monitors, separators=(",", ":")) + "\n")
    sys.stdout.write(json.dumps(clients, separators=(",", ":")) + "\n")


def cursor():
    x = y = 0
    for o in jget("get_outputs"):
        if o.get("focused"):
            r = o.get("rect", {})
            x = r.get("x", 0) + r.get("width", 0) // 2
            y = r.get("y", 0) + r.get("height", 0) // 2
            break
    sys.stdout.write(json.dumps({"x": x, "y": y}) + "\n")


def move(payload):
    try:
        items = json.loads(payload)
    except Exception:
        return
    cmds = []
    for it in items:
        sel = "[con_id=%d]" % int(it["id"])
        if it.get("float"):
            cmds.append("%s floating enable" % sel)
        if it.get("w") is not None and it.get("h") is not None:
            cmds.append("%s resize set width %d px height %d px" % (sel, int(it["w"]), int(it["h"])))
        cmds.append("%s move absolute position %d px %d px" % (sel, int(it["x"]), int(it["y"])))
    if cmds:
        sway("; ".join(cmds))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "snapshot"
    if cmd == "snapshot":
        snapshot()
    elif cmd == "cursor":
        cursor()
    elif cmd == "move" and len(sys.argv) > 2:
        move(sys.argv[2])
