# acceptance-debt — what shipped and nobody has looked at

**The user cannot look at every round.** A round that ships without being looked at used to leave no trace
at all, so the next session read `3.done/` as "accepted" and built on top of it. **This file is that trace**,
and it exists to be worked off **in one sitting**, not one item at a time.

⚠ **A row here is not a bug.** It is a thing that is built, green, and unwitnessed.

## How a row arrives

**At `wrap-up`, one question is asked and the answer decides:**

- **The user says they looked** → the verdict goes under the design doc's `Accepted` section **that turn**,
  and any row here for it is deleted
- **They did not, or said nothing** → a row is added here. ⚠ **Silence is a row**, not a pass

## How a row leaves

**Only the user's own words remove it**, and **the verdict is written into the design doc in the same
breath.** ⇒ **Deleting a row without writing the verdict loses the one thing the row existed to collect.**
A `fail` closes a row exactly as a `pass` does — what was wrong goes into the design doc.

## How to write "How to see it"

**This column is the whole value of the file.** When the user sits down to work the list off, they are not
going to re-derive how to reach each thing. **Name the screen, the key, and what should be different** —
if it cannot be reached in the running game, say that instead, because that is itself the finding.

| # | What shipped | How to see it | Where the verdict goes | Landed |
|---|---|---|---|---|
