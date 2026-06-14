# How shipmate protects your main branch

Three layers, weakest to strongest:

1. **Local hook** — stops *you* from committing to `main` by accident. Bypassable
   (`git commit --no-verify`), so it is convenience, not security.
2. **GitHub branch protection** — the real wall. GitHub refuses any direct push to
   `main` server-side, even if your local hook is off. This is what actually enforces.
3. **Required status checks (CI)** — your CI must pass before a pull request can merge.
   A CI run cannot *block a push* (the push already happened); it gates the *merge*.

shipmate sets up whichever layers you opt into. Tags are intentionally exempt from
protection so releases can be tagged after merge.
