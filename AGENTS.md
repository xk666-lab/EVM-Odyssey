# Repository Guidelines

## Project Structure & Module Organization
- Markdown driven curriculum split into numbered folders `00-*` through `34-*`, each covering a specific Ethereum or Web3 topic. Keep modules self-contained: overview, deep dives, exercises.
- `assets/` stores shared visuals (`diagrams/`), screenshots (`images/`), code excerpts (`code-snippets/`), and Markdown templates (`templates/`). Reuse existing assets; add new ones beside the source module.
- Utility scripts (for example `expand_defi_basics.js`) scaffold content. Place additional tooling under the project root with clear names.

## Build, Test, and Development Commands
- `node expand_defi_basics.js` – example generator that expands the DeFi module directory tree. Use similar scripts to scaffold learning paths; keep them idempotent.
- `npm test` – placeholder for future automated checks. If you introduce runnable code or graders, wire them to this command.

## Coding Style & Naming Conventions
- Markdown: use `#`-based headings, emoji sparingly for emphasis, and fenced code blocks with info strings (` ```solidity``, ` ```bash```). Start files with a level-one title matching the folder context.
- JavaScript utilities: prefer modern ES2019+, two-space indentation, single quotes, and trailing commas where allowed. Document non-obvious functions in inline comments.
- File names: follow the numeric prefix pattern already used (`15.0-*`, `03-*`). Keep ASCII/UTF-8 consistency; mirror Chinese titles from existing modules if you add new content.

## Testing Guidelines
- For narrative content, create review checklists in each module’s `README.md` to capture acceptance criteria.
- When adding executable code or scripts, provide sample input/output and, where feasible, lightweight unit tests (e.g., Jest) under a sibling `tests/` directory. Run them via `npm test`.

## Commit & Pull Request Guidelines
- Use action-oriented, present-tense commit messages (`Add AMM math walkthrough`, `Update DAO governance checklist`). Group related Markdown edits together.
- PRs should include: purpose summary, list of key sections touched (e.g., `15-DeFi协议深度拆解/03-*`), screenshots or rendered previews for diagrams, and references to related issues or study feedback.

## Security & Configuration Tips
- Do not commit API keys or private RPC URLs; place sensitive examples in `.env.example` under the relevant module if needed.
- Scripts that touch the filesystem must guard against overwriting existing content (`fs.existsSync`) and respect the numbered module hierarchy.
