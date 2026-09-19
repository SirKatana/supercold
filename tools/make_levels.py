#!/usr/bin/env python3
"""Generates the HQ floor grids into levels/. Re-run after editing: python3 tools/make_levels.py
Hand edits to the generated .txt files are overwritten, so change the floor here instead."""
import json
import os

OUT = os.path.join(os.path.dirname(__file__), "..", "levels")


class Grid:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.c = [["#"] * w for _ in range(h)]

    def room(self, x0, y0, x1, y1):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.c[y][x] = "."

    def put(self, ch, *cells):
        for x, y in cells:
            assert self.c[y][x] in ".#", f"cell {x},{y} already holds {self.c[y][x]!r}"
            self.c[y][x] = ch

    def text(self):
        return "\n".join("".join(r) for r in self.c) + "\n"


def save(name, grid, meta):
    with open(os.path.join(OUT, name + ".txt"), "w") as f:
        f.write(grid.text())
    with open(os.path.join(OUT, name + ".json"), "w") as f:
        json.dump(meta, f, indent=2)
        f.write("\n")
    print(f"{name}: {grid.w}x{grid.h}")


def f1_lobby():
    g = Grid(20, 14)
    g.room(1, 1, 18, 7)
    g.room(1, 9, 18, 12)
    g.put("#", *[(x, y) for x in (9, 10) for y in (1, 2, 3, 4)])
    g.put(".", (4, 8), (5, 8), (14, 8), (15, 8))          # turnstile gaps
    g.put("P", (2, 2))
    g.put("p", (4, 4))
    g.put("c", (5, 6), (6, 6), (13, 6), (14, 6), (9, 10), (10, 10))
    g.put("a", (15, 2), (2, 10), (17, 10), (5, 12))
    g.put("b", (6, 10))
    g.put("m", (13, 10))
    g.put("X", (10, 12))
    save("f1_lobby", g, {"intro": "LOBBY\nSTAND STILL. TIME CRAWLS."})


def f2_offices():
    g = Grid(30, 22)
    g.room(1, 1, 8, 5)       # start
    g.room(1, 7, 8, 14)      # west corridor
    g.room(10, 1, 28, 14)    # cubicle hall
    g.room(1, 16, 13, 20)    # south west
    g.room(15, 16, 28, 20)   # south east
    g.put("D", (4, 6), (9, 3), (9, 11), (5, 15), (20, 15), (14, 18))
    for y in (3, 6, 9, 12):
        for x in (12, 17, 22):
            g.put("c", (x, y), (x + 1, y))
    g.put("P", (2, 2))
    g.put("X", (27, 19))
    g.put("a", (15, 4), (21, 7), (26, 10), (14, 13), (4, 11), (22, 18))
    g.put("u", (7, 18))
    g.put("b", (7, 2))
    g.put("k", (2, 4))
    g.put("m", (11, 8))
    g.put("l", (19, 10))
    g.put("p", (27, 2))
    save("f2_offices", g, {"intro": "OFFICES\nTHROW THINGS. TAKE THEIR GUNS."})


def f3_servers():
    g = Grid(28, 20)
    g.room(1, 1, 6, 5)       # start
    g.room(1, 7, 6, 12)      # control room
    g.room(8, 1, 26, 12)     # server hall
    g.room(1, 14, 26, 18)    # south corridor
    g.put("D", (7, 3), (3, 6), (3, 13), (12, 13), (22, 13))
    g.put("G", (7, 8), (7, 9), (7, 10), (7, 11))
    for x in (10, 14, 18, 22):
        for y in (2, 3, 4, 5, 8, 9, 10, 11):
            g.put("s", (x, y))
    g.put("P", (2, 2))
    g.put("X", (25, 17))
    g.put("a", (12, 3), (16, 10), (20, 4), (24, 9), (4, 9), (8, 16), (18, 16))
    g.put("u", (14, 16))
    g.put("b", (5, 2))
    g.put("k", (5, 11))
    g.put("l", (9, 7))
    g.put("m", (20, 15))
    save("f3_servers", g, {"intro": "SERVER ROOM\nDOORS BREAK. SO DO THEY."})


def f4_labs():
    g = Grid(36, 24)
    g.room(1, 11, 34, 12)    # long corridor
    for x0 in (1, 12, 24):
        g.room(x0, 1, x0 + 10 if x0 > 1 else 10, 9)
        g.room(x0, 14, x0 + 10 if x0 > 1 else 10, 22)
    g.put("D", (5, 10), (17, 10), (29, 10), (5, 13), (17, 13), (29, 13))
    g.put("G", (7, 10), (8, 10), (19, 10), (20, 10), (31, 13), (32, 13))
    g.put("P", (2, 12))
    g.put("X", (33, 21))
    g.put("a", (14, 11), (24, 12), (33, 11), (5, 4), (17, 5), (29, 4), (5, 18), (17, 18), (29, 17))
    g.put("u", (8, 20))
    g.put("w", (34, 11), (34, 12))
    g.put("p", (4, 11), (30, 20))
    g.put("b", (16, 3))
    g.put("k", (28, 3))
    g.put("m", (6, 17))
    g.put("l", (18, 20))
    g.put("c", (3, 3), (4, 3), (15, 7), (16, 7), (27, 7), (28, 7), (3, 16), (4, 16), (15, 16), (27, 20))
    save("f4_labs", g, {
        "intro": "LABS\nLONG HALLS. WATCH THE BULLETS.",
        "waves": [{"after_kills": 6, "count": 4, "armed": 3}],
    })


def f5_executive():
    g = Grid(40, 28)
    g.room(1, 1, 12, 8)      # reception
    g.room(1, 10, 12, 17)    # west office 1
    g.room(1, 19, 12, 26)    # west office 2
    g.room(14, 1, 38, 14)    # boardroom
    g.room(14, 16, 38, 18)   # corridor
    g.room(14, 20, 25, 26)   # exec office south west
    g.room(27, 20, 38, 26)   # exec office south east
    g.put("D", (13, 4), (6, 9), (6, 18), (13, 17), (20, 15), (32, 15), (22, 19), (29, 19))
    g.put("G", (17, 19), (18, 19), (19, 19), (32, 19), (33, 19), (34, 19))
    for x in range(18, 35, 2):
        g.put("c", (x, 7), (x, 8))
    g.put("P", (2, 2))
    g.put("X", (37, 25))
    g.put("a", (9, 6), (17, 3), (24, 4), (31, 3), (36, 10), (28, 11), (4, 13), (5, 23), (26, 17), (33, 23))
    g.put("u", (9, 15), (18, 23))
    g.put("w", (14, 17), (38, 17), (2, 26))
    g.put("p", (3, 6), (37, 21))
    g.put("b", (10, 2), (3, 21))
    g.put("k", (16, 10), (24, 16))
    g.put("m", (35, 5))
    g.put("l", (8, 12))
    save("f5_executive", g, {
        "intro": "EXECUTIVE FLOOR\nEVERYTHING YOU LEARNED.",
        "waves": [{"after_kills": 5, "count": 4, "armed": 3}, {"after_kills": 10, "count": 5, "armed": 4}],
    })


def roof():
    g = Grid(30, 30)
    g.room(4, 4, 25, 25)     # arena
    g.room(13, 1, 16, 2)     # north stairwell
    g.room(13, 27, 16, 28)   # south stairwell
    g.room(1, 13, 2, 16)     # west stairwell
    g.room(27, 13, 28, 16)   # east stairwell
    g.put("D", (14, 3), (15, 26), (3, 14), (26, 15))
    g.put("w", (14, 1), (15, 28), (1, 15), (28, 14))
    g.put("s", (9, 9), (20, 9), (9, 20), (20, 20), (14, 12), (15, 18))
    g.put("c", (11, 15), (12, 15), (18, 15), (19, 15))
    g.put("P", (6, 23))
    g.put("B", (15, 7))
    g.put("X", (15, 15))
    g.put("a", (10, 6), (20, 6))
    g.put("p", (7, 15), (23, 15))
    g.put("b", (15, 22))
    g.put("k", (5, 5))
    g.put("m", (24, 24))
    g.put("l", (24, 5))
    save("roof", g, {"intro": "ROOF\nTHE DIRECTOR. THREE BULLETS.", "open_sky": True})


if __name__ == "__main__":
    f1_lobby()
    f2_offices()
    f3_servers()
    f4_labs()
    f5_executive()
    roof()
