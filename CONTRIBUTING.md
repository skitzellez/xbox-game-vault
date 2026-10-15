# Contributing

Help is welcome, and you do not need to be a programmer to be useful.

## Ways to help

- **Test a game and report it.** Open an issue with: the game and region, the file format, the app versions,
  what happened, and for xemu the `uwp_debug.log` from `LocalState\xemu\xemu` (it holds frame rates and
  profiler lines). "Works fine" reports are as useful as failures.
- **Fix something in the emulators.** Their source is public: the `xemu-uwp` fork (branch `uwp`) and the
  `RetroArch-GameVault` / `XBSX2-GameVault` forks (branch `gamevault`). Small pull requests are easiest to review.
- **Ideas for Game Vault itself** (a system to add, a feature): open an issue. Game Vault's own code is not
  published, so changes to it are made by its author.
- **Improve the setup instructions** if a step was unclear or wrong for you.

## Where things go

- This repository: the README, the setup program, the docs and the emulators' build scripts and patches.
- Emulator changes: the `xemu-uwp` fork, branch `uwp`. Keep changes inside `#ifdef XEMU_UWP` so the desktop
  build is not affected.

## Rules

- **No games, BIOS files, keys, or links to them**, in issues, pull requests or commits. Use homebrew
  (for example `nxdk_pgraph_tests`, `xemu-perf-tests`, `240p-test-mini`) when a test file is needed.
- No passwords, console addresses or signing certificates in commits. Private settings belong in the
  untracked files the scripts read (`portal.local`, `cert\password.txt`).
- AI-assisted contributions are fine here; say so in the pull request. Please do **not** send this code to
  QEMU or SDL: those projects decline AI-generated contributions. xemu permits AI-assisted pull requests only
  from someone who understands, has tested and can defend every line (see its `CONTRIBUTING.md`); do not
  forward code from here to xemu unless you can do that.
- Say what you tested and on which console. Untested changes are acceptable if they are labelled as such.

## Licences

This repository is under the PolyForm Noncommercial License 1.0.0 with a required credit notice (see
`LICENSE`): free to use, change and share for noncommercial purposes, not to sell, and the Skitzelles credit
stays. By sending a pull request you agree that your contribution is offered under the same terms. You keep
your own copyright and will be credited in the commit history.

Contributions to the `xemu-uwp` fork are under GPL version 2, like xemu itself.
