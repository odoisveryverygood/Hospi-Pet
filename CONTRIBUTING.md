# Contributing

`main` is the canonical maintained branch. Open pull requests against `main`.
CI runs the check commands and audit separately from Chromium acceptance.
Use the Node version in `.nvmrc`; install the browser with
`npx playwright install --with-deps chromium` before running browser tests.

The maintained surface is `src/` and its tests. Keep changes focused on capture
ownership, cleanup, reproducibility, and explicit evidence. Run `npm run check`
and `npm run test:browser` before proposing a change. Never commit real audio,
transcripts, private medical data, populated environment files, or credentials.

`legacy/jac-app/` preserves the original research at `82b9211`; its original
ownership/partner documents are historical. Avoid silently modifying archived
research or treating its tests as coverage of the maintained controller.
Do not push, deploy, or rewrite history without explicit authorization.
