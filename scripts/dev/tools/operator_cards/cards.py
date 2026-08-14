"""Cards the operator photographed, transcribed for load_operator_card.py.

Each entry is one club card. The printed OUT, IN and TOTAL are what makes a
transcription checkable, so they are copied exactly as the card states them —
never recomputed from the cells above, which would make the check circular.
"""

CARDS = {
    # Phoenix Golf Resort, Champion Course. Photographed by the operator,
    # 2026-08-14; the card had been played on, so it also carries four golfers'
    # handwriting, which is not part of the club's card and is ignored.
    #
    # WHAT THIS CARD IS FOR
    #
    #   The stroke index. Golfify supplied this course's card and gave it
    #   1,3,5..17 on the front and 2,4,6..18 on the back — hole 1 index 1,
    #   hole 2 index 3, straight down the card. That is not a ranking of
    #   difficulty, it is the sequence a program writes when it has none. The
    #   club's own card ranks them 7,5,15,9,1,3,17,11,13 and 6,14,12,18,8,16,
    #   10,2,4, and stroke index exists in no open dataset — a photograph is
    #   the only way it can ever be known.
    #
    #   Par and the Black yardages already agree with what is stored, to the
    #   last number, which is what says the transcription below is right.
    #
    # WHITE, GOLD AND RED ARE NOT HERE
    #
    #   Their front nines do not reconcile against the totals the club prints:
    #   White reads four yards over its printed 3,218, Gold twenty under its
    #   3,005, and Red's hole 5 reads longer off Red than off Gold, which no
    #   card does. Each is one cell misread off a creased photograph, and the
    #   card does not say which cell. Their back nines are all three exact.
    #   Left out rather than guessed — a second photograph of the left half of
    #   the card settles them.
    "PHOENIX_CHAMPION": {
        "club": "Phoenix Golf Resort",
        "name": "Champion Course",
        "source": "club card photographed at the course",
        "tees": ["Black", "Blue"],
        # hole, par, stroke index, Black, Blue
        "holes": [
            (1, 4, 7, 407, 385),
            (2, 4, 5, 483, 445),
            (3, 3, 15, 186, 163),
            (4, 5, 9, 621, 604),
            (5, 4, 1, 413, 380),
            (6, 4, 3, 470, 437),
            (7, 5, 17, 525, 504),
            (8, 4, 11, 440, 403),
            (9, 3, 13, 192, 174),
            (10, 4, 6, 455, 420),
            (11, 5, 14, 590, 568),
            (12, 3, 12, 221, 188),
            (13, 4, 18, 397, 348),
            (14, 4, 8, 400, 379),
            (15, 3, 16, 215, 188),
            (16, 4, 10, 426, 398),
            (17, 5, 2, 619, 580),
            (18, 4, 4, 426, 398),
        ],
        # OUT, IN, TOTAL exactly as the card prints them.
        "totals": {
            "par": (36, 36, 72),
            "Black": (3737, 3749, 7486),
            "Blue": (3495, 3467, 6962),
        },
    },
}
