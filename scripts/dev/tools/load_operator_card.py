#!/usr/bin/env python3
"""Load a club card the operator transcribed, once it agrees with itself.

    python3 load_operator_card.py <CARD_NAME> <course_id> [--drop Red,Blue]

The cards live in operator_cards/cards.py, one dict each: the tee names, a row
per hole as (hole, par, stroke index, *yards per tee), and the OUT, IN and
TOTAL the source prints for every tee.

WHY THE TOTALS MATTER MORE THAN THE CELLS
-----------------------------------------
These arrive as tables rather than photographs, and a table can be a faithful
transcription or a reconstruction — there is no way to tell by looking. The
printed totals are what tells them apart: eighteen holes across five tees is
ninety numbers, and a table that sums to the OUT, IN and TOTAL it states for
every one of five tees was not invented.

It caught real errors. Royal Ninh Bình's file silently filled a blank Gold cell
with the Blue value and left the total unchanged, so its Gold column read 3,053
against a printed 2,741 — the photograph of the same card was self-consistent
and the file was not. PGA Ocean's five OUT totals were each about 200 yards
over, which is a table built from a different tee configuration. Neither was
loaded.

Where only some tees disagree, `--drop` leaves those out and takes the rest: a
Red column that misses its total by ten yards says one Red cell is wrong and
gives no way to find it, but it says nothing about Black.

THE CHECK THAT MATTERS MOST
---------------------------
No two courses may share a par sequence and a stroke index sequence.

Everything else here tests a table against itself, and that is exactly what a
generated table passes: the generator computes the totals from the numbers it
invented, so they agree perfectly. Twelve of the tables supplied for this
project carried the same eighteen pars AND the same eighteen stroke indexes as
each other — Corn Hill, Yên Bái Star, Silk Path, FLC's Ocean Dunes, ANARA,
Tuần Châu, Xuân Thành, Yên Dũng, Vinpearl Nha Trang and more. Two real courses
do not agree on all thirty-six of those numbers. Nine had already been loaded
before anyone compared them to each other.

So this compares every incoming card against every card already stored. It is
the only check here that cannot be satisfied by a table that is internally
tidy, because it asks a question about the world rather than about the table.

WHAT ELSE IS CHECKED
--------------------
  * par sums to the stated OUT, IN and TOTAL
  * every tee sums to its stated OUT, IN and TOTAL
  * stroke indexes are n distinct values inside 1..2n
  * no hole is longer off a shorter tee than off a longer one

The last is new here, and is what flagged Royal's blank cell: tees on one hole
run long to short, so a Gold that reads under its own Blue is a misprint.

Red is written as the ladies' tee where the source labels it "(Nữ)". Every
other tee is UNSPECIFIED — the source does not say, and reading an unlabelled
rating as the men's would be a guess that looks like data.
"""
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent / "operator_cards"))
