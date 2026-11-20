# The Rift Creep maps, in order of depth into the rift. Tiles are (u, v) on the 15 x 15 diamond: +u runs right-down
# on screen, +v right-up, (0, 0) is the left corner. Every road ends running +v into the portal, like Rift Plaza's.

def rect(u0, u1, v0, v1):
    return [(u, v) for u in range(u0, u1 + 1) for v in range(v0, v1 + 1)]


def equalize(lanes):
    """Every lane must be as long (so an enemy's distance means the same on any of them): the shorter ones start
    further back along their first leg, off the board."""
    st = lambda legs: sum(abs(b[0] - a[0]) + abs(b[1] - a[1]) for a, b in zip(legs, legs[1:]))
    n = max(st(l) for l in lanes)
    out = []
    for legs in lanes:
        legs = [tuple(p) for p in legs]
        k = n - st(legs)
        (u0, v0), (u1, v1) = legs[0], legs[1]
        du, dv = (u0 > u1) - (u0 < u1), (v0 > v1) - (v0 < v1)
        out.append([(u0 + du * k, v0 + dv * k)] + legs[1:])
    return out


MAPS = {
    # Map 4: two entries, from the bottom and the top, wind in and join at the plaza's west end; the joined road
    # spirals to the portal. The first map where the rift has cracked the city open.
    'fronts': {
        'out': 'map3_fronts', 'seed': 31, 'rift': 0.35,
        'lanes': [
            [(21, 5), (12, 5), (12, 1), (3, 1), (3, 3), (10, 3), (10, 10), (5, 10), (5, 5), (7, 5), (7, 7)],
            [(5, 21), (5, 12), (1, 12), (1, 3), (3, 3), (10, 3), (10, 10), (5, 10), (5, 5), (7, 5), (7, 7)],
        ],
        'scars': [(13, 12), (0, 7)],
        'hero': (4, 4),
    },
    # Map 5: a canal splits the square; the road crosses it on four narrow bridges, where the hero blocks best.
    'bridges': {
        'out': 'map4_bridges', 'seed': 41, 'rift': 0.6,
        'lanes': [[(1, -4), (1, 13), (4, 13), (4, 1), (13, 1), (13, 13), (10, 13), (10, 4), (7, 4), (7, 7)]],
        'water': [(u, 7) for u in list(range(0, 6)) + list(range(9, 15))] + [(u, 8) for u in list(range(0, 6)) + list(range(9, 15))],
        'scars': [(7, 12), (7, 1)],
        'hero': (3, 3),
    },
    # Map 6: the road crosses itself twice. A tower by a crossing hits every enemy twice.
    'crossroads': {
        'out': 'map5_crossroads', 'seed': 51, 'rift': 0.8,
        'lanes': [[(5, -5), (5, 13), (13, 13), (13, 9), (1, 9), (1, 2), (9, 2), (9, 5)]],
        'crossings': [(5, 9), (5, 2)], 'mark_crossings': True,
        'scars': [(11, 4), (3, 12), (12, 6)],
        'hero': (7, 7),
    },
    # Map 7, the finale: the city is torn into floating islands. Three lanes cross the void on light bridges, join at
    # the south-east corner and orbit the portal island on a ring of light. Towers only go on islands.
    'islands': {
        'out': 'map6_islands', 'seed': 61, 'rift': 1.0,
        'lanes': equalize([
            [(3, -6), (3, 1), (11, 1), (11, 3), (11, 11), (3, 11), (3, 5), (7, 5), (7, 7)],
            [(-6, 7), (1, 7), (1, 3), (11, 3), (11, 11), (3, 11), (3, 5), (7, 5), (7, 7)],
            [(22, 8), (13, 8), (13, 3), (11, 3), (11, 11), (3, 11), (3, 5), (7, 5), (7, 7)],
        ]),
        'islands': rect(4, 10, 4, 10) + rect(4, 10, 0, 2) + rect(0, 2, 4, 10) + rect(4, 10, 12, 14) + rect(12, 14, 4, 10)
                   + rect(12, 14, 12, 14) + rect(0, 1, 0, 1),
        'hero': (10, 2),
    },
}
