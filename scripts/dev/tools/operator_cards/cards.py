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

    # Hilltop Valley Golf Club, A COURSE and B COURSE — one card printed for
    # the pairing, so each nine is transcribed as its own đường.
    #
    # It reconciles ten times over: par and all four tees against the OUT the
    # card prints for A, and the same again against the IN for B. Nothing was
    # dropped.
    #
    # WHAT IT CORRECTS
    #
    #   Three cells of the mscorecard export already stored, each provably
    #   wrong because the club's own total agrees with the card and not with
    #   the store:
    #     A White hole 4 — 422 stored, 379 printed. 422 is Blue's hole 4, a
    #       column copied one row across; A White sums to its printed 2,588
    #       with 379 and to 2,631 with 422.
    #     B Red hole 11 — 332 stored, 292 printed. 332 is Black's hole 10.
    #     A Red hole 3 — 358 stored, 359 printed.
    #
    #   And the stroke index. The store has A ranked 9,15,1,3,13,7,11,17,5 and
    #   B ranked 13,1,5,11,15,7,17,9,3 — both nines carrying the odd numbers,
    #   which cannot be: two nines played as one eighteen share 1..18 between
    #   them. That is the artefact of an export that lists every nine as an
    #   eighteen. The club ranks each nine 1..9 in its own right.
    "HILLTOP_A": {
        "club": "Hilltop Valley Golf Club",
        "name": "A Course",
        "source": "club A+B card photographed at the course",
        "tees": ["Black", "Blue", "White", "Red"],
        # hole, par, stroke index, Black, Blue, White, Red
        "holes": [
            (1, 4, 5, 357, 337, 275, 255),
            (2, 3, 8, 169, 148, 113, 77),
            (3, 5, 1, 580, 547, 427, 359),
            (4, 4, 2, 455, 422, 379, 290),
            (5, 3, 7, 221, 180, 125, 106),
            (6, 5, 4, 572, 528, 486, 466),
            (7, 4, 6, 325, 298, 277, 228),
            (8, 3, 9, 181, 172, 158, 103),
            (9, 4, 3, 471, 398, 348, 302),
        ],
        "totals": {"par": 35, "Black": 3331, "Blue": 3030,
                   "White": 2588, "Red": 2186},
    },

    # B COURSE. The card numbers these 10-18 because it is printed for the A+B
    # pairing; đường B is its own nine, so they are renumbered 1-9 here.
    "HILLTOP_B": {
        "club": "Hilltop Valley Golf Club",
        "name": "B Course",
        "source": "club A+B card photographed at the course",
        "tees": ["Black", "Blue", "White", "Red"],
        "holes": [
            (1, 4, 7, 332, 321, 298, 253),
            (2, 4, 1, 453, 416, 350, 292),
            (3, 5, 3, 528, 508, 472, 432),
            (4, 3, 6, 214, 198, 155, 97),
            (5, 4, 8, 372, 315, 292, 199),
            (6, 4, 4, 398, 352, 322, 172),
            (7, 4, 9, 493, 431, 410, 293),
            (8, 3, 5, 185, 172, 159, 132),
            (9, 5, 2, 602, 572, 539, 484),
        ],
        "totals": {"par": 36, "Black": 3577, "Blue": 3285,
                   "White": 2997, "Red": 2354},
    },

    # Tam Đảo Golf & Resort, photographed at the club. Every one of fifteen
    # printed sums reconciles — four tees over two nines plus par, OUT, IN and
    # TOTAL — so nothing is dropped.
    "TAM_DAO": {
        "club": "Tam Đảo Golf & Resort",
        "name": "Championship",
        "source": "club card photographed at the course",
        "tees": ["Gold", "Blue", "White", "Red"],
        "holes": [
            (1, 5, 9, 524, 492, 452, 410),
            (2, 3, 15, 152, 139, 108, 99),
            (3, 4, 5, 437, 392, 361, 306),
            (4, 5, 3, 554, 521, 480, 398),
            (5, 4, 1, 457, 421, 383, 342),
            (6, 4, 11, 416, 386, 338, 297),
            (7, 4, 13, 375, 346, 314, 272),
            (8, 3, 17, 204, 161, 142, 106),
            (9, 4, 7, 424, 397, 347, 305),
            (10, 5, 14, 536, 511, 476, 445),
            (11, 4, 12, 353, 325, 293, 247),
            (12, 3, 10, 194, 190, 136, 130),
            (13, 4, 2, 466, 441, 386, 326),
            (14, 4, 16, 418, 368, 354, 306),
            (15, 5, 6, 568, 539, 516, 412),
            (16, 4, 8, 427, 395, 362, 276),
            (17, 3, 18, 217, 189, 173, 141),
            (18, 4, 4, 447, 390, 344, 301),
        ],
        "totals": {
            "par": (36, 36, 72),
            "Gold": (3543, 3626, 7169),
            "Blue": (3255, 3348, 6603),
            "White": (2925, 3040, 5965),
            "Red": (2535, 2584, 5119),
        },
        # The card prints these unlabelled, so none is read as the men's.
        "ratings": {
            "Gold": {"UNSPECIFIED": (75.2, 144)},
            "Blue": {"UNSPECIFIED": (72.6, 139)},
            "White": {"UNSPECIFIED": (69.7, 133)},
            "Red": {"UNSPECIFIED": (71.1, 136)},
        },
    },

    # Dragon Golf Links (Sầm Sơn), photographed at the club. Fifteen printed
    # sums, all fifteen reconcile.
    "DRAGON_LINKS": {
        "club": "Dragon Golf Links",
        "name": "Championship",
        "source": "club card photographed at the course",
        "tees": ["Black", "Blue", "White", "Red"],
        "holes": [
            (1, 4, 15, 376, 347, 300, 253),
            (2, 4, 13, 366, 343, 301, 240),
            (3, 3, 5, 232, 208, 170, 148),
            (4, 5, 7, 594, 570, 508, 478),
            (5, 4, 17, 319, 302, 273, 197),
            (6, 4, 1, 418, 395, 327, 294),
            (7, 5, 9, 576, 548, 464, 430),
            (8, 3, 11, 209, 199, 160, 141),
            (9, 4, 3, 450, 410, 361, 321),
            (10, 4, 6, 432, 395, 354, 301),
            (11, 4, 10, 400, 378, 309, 262),
            (12, 3, 18, 139, 123, 103, 87),
            (13, 5, 8, 618, 594, 552, 486),
            (14, 4, 16, 374, 353, 288, 251),
            (15, 4, 2, 493, 469, 436, 402),
            (16, 3, 14, 205, 189, 171, 150),
            (17, 4, 4, 460, 440, 387, 360),
            (18, 5, 12, 593, 555, 490, 460),
        ],
        "totals": {
            "par": (36, 36, 72),
            "Black": (3540, 3714, 7254),
            "Blue": (3322, 3496, 6818),
            "White": (2864, 3090, 5954),
            "Red": (2502, 2759, 5261),
        },
        "ratings": {
            "Black": {"UNSPECIFIED": (75.0, 134)},
            "Blue": {"UNSPECIFIED": (73.0, 130)},
            "White": {"UNSPECIFIED": (69.1, 122)},
            "Red": {"UNSPECIFIED": (70.0, 123)},
        },
    },

    # Yên Bái Star Golf — Đường Cọ / Palm Course (B). All four tees reconcile
    # against the TOTAL row, and again against the club's own rating
    # certificate on the same card, which states Palm as 3430/3185/2860/2600.
    #
    # The certificate rates each nine at 34-37, which the database cannot hold:
    # scorecard_tees checks course_rating between 60 and 80, an eighteen-hole
    # range. The nine-hole ratings are left off rather than doubled.
    "YENBAI_PALM": {
        "club": "Yên Bái Star Golf",
        "name": "Đường Cọ / Palm Course (B)",
        "source": "club card photographed at the course",
        "tees": ["Gold", "Blue", "White", "Red"],
        "holes": [
            (1, 4, 18, 330, 300, 265, 240),
            (2, 4, 6, 400, 370, 330, 305),
            (3, 5, 12, 560, 530, 500, 470),
            (4, 4, 14, 375, 340, 320, 275),
            (5, 3, 10, 205, 170, 140, 110),
            (6, 4, 2, 390, 360, 310, 265),
            (7, 3, 8, 190, 185, 120, 120),
            (8, 4, 4, 470, 430, 415, 380),
            (9, 5, 16, 510, 500, 460, 435),
        ],
        "totals": {"par": 36, "Gold": 3430, "Blue": 3185,
                   "White": 2860, "Red": 2600},
    },

    # Đường Quế / Cinnamon Course (A), Gold only. Glare across the middle of
    # the photograph hides holes 3 and 4 on Blue, White and Red; Gold is clear
    # and sums to the 3,505 both the TOTAL row and the rating certificate
    # print. The other three tees need the card photographed again.
    "YENBAI_CINNAMON": {
        "club": "Yên Bái Star Golf",
        "name": "Đường Quế / Cinnamon Course (A)",
        "source": "club card photographed at the course",
        "tees": ["Gold"],
        "holes": [
            (1, 4, 5, 400),
            (2, 5, 11, 540),
            (3, 4, 17, 380),
            (4, 3, 15, 155),
            (5, 4, 1, 405),
            (6, 3, 13, 185),
            (7, 4, 7, 420),
            (8, 5, 9, 590),
            (9, 4, 3, 430),
        ],
        "totals": {"par": 36, "Gold": 3505},
    },

    # FLC Golf Club Hạ Long, photographed at the club. Par 71, not the 72 a
    # seed assumes. All fifteen printed sums reconcile.
    #
    # White hole 6 reads 232 against Blue's 395 — a 163-yard drop that looks
    # like a misread and is not: White sums to its printed 2,615 with 232 and
    # to 2,715 with 332. The card's own arithmetic settles it.
    "FLC_HA_LONG": {
        "club": "FLC Golf Club Hạ Long",
        "name": "Championship",
        "source": "club card photographed at the course",
        "tees": ["Black", "Blue", "White", "Red"],
        "holes": [
            (1, 4, 16, 358, 341, 323, 255),
            (2, 5, 18, 472, 432, 412, 359),
            (3, 4, 6, 345, 293, 271, 234),
            (4, 5, 10, 530, 506, 440, 400),
            (5, 3, 8, 200, 194, 147, 107),
            (6, 4, 2, 423, 395, 232, 195),
            (7, 4, 4, 415, 373, 307, 269),
            (8, 3, 12, 192, 181, 166, 149),
            (9, 4, 14, 383, 344, 317, 291),
            (10, 4, 11, 358, 327, 306, 240),
            (11, 4, 1, 457, 412, 332, 239),
            (12, 3, 17, 119, 109, 96, 73),
            (13, 3, 15, 164, 150, 138, 100),
            (14, 5, 7, 634, 604, 556, 489),
            (15, 5, 3, 553, 480, 453, 432),
            (16, 3, 13, 204, 175, 156, 131),
            (17, 4, 5, 441, 423, 358, 294),
            (18, 4, 9, 411, 353, 332, 268),
        ],
        "totals": {
            "par": (36, 35, 71),
            "Black": (3318, 3341, 6659),
            "Blue": (3059, 3033, 6092),
            "White": (2615, 2727, 5342),
            "Red": (2259, 2266, 4525),
        },
        "ratings": {
            "Black": {"UNSPECIFIED": (72.5, 136)},
            "Blue": {"UNSPECIFIED": (69.6, 128)},
            "White": {"UNSPECIFIED": (65.7, 120)},
            "Red": {"UNSPECIFIED": (67.1, 116)},
        },
    },
}
