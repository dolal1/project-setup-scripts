# Tiered Modules: the shared contract

The tiered scaffolders (`setup_<stack>_tiered_project.sh`) create apps that are sold in tiers,
for example Basic, Standard and Premium. One development repo holds every tier, so any tier can
be switched on locally and in tests. A client release contains **only** the tiers that client
has: higher tiers are removed from the code, not hidden behind a flag, so they can't be unlocked
by editing config.

This document is the contract every stack implements. The per-stack sections at the end say how.

## Terms

| Term | Meaning |
| --- | --- |
| **Tier** | An ordered level, lowest first, e.g. `basic,standard,premium` |
| **Core** | The first tier. It lives in the app's normal folders and is always shipped |
| **Module** | Every later tier. Each one is a self-contained folder under `modules/` |
| **Prefix** | A short project name for settings: prefix `salon` gives `SALON_TIER` |
| **Active tier** | The value of `<PREFIX>_TIER`. Modules at or below it are loaded |

## Rules

1. **Core never references a module.** No imports, class names, route names, template names or
   table names from `modules/` appear anywhere outside `modules/`. An arch test enforces it.
2. **Modules plug into core through hooks.** Core exposes registries (menu, reports, form
   sections and so on); a module's entry point registers itself in them. Core only loops over
   what's registered.
3. **A module brings everything it needs:** routes, views, migrations, permissions, feature
   switches and tests. Removing the folder removes all of it, including its database tables.
4. **The loader is forgiving.** It loads every module whose tier is at or below the active tier
   **and whose folder exists**. If the active tier's module is missing (as in a lower-tier
   release), it logs a warning and carries on.
5. **A module may require a lower module** (Premium requires Standard). The loader refuses to
   load a module whose requirement is missing.
6. **Feature switches are runtime-only.** Each module defines its own switches, on by default.
   A switch that was never defined is off. Switches exist to turn delivered features off for a
   while or to try them on one account, never to enforce tiers.
7. **Permissions check presence and role together.** Each permission declares its roles and,
   optionally, its feature switch. The check passes only if the permission is defined, its
   switch is on, and the user's role is listed. **An undefined permission denies.** So a lower
   tier release shows no buttons for missing features, and nothing errors.
8. **Module routes live in the module.** A removed module has no URLs at all, so they 404.

## Files every tiered project has

| File | Purpose |
| --- | --- |
| `modules/<Tier>/<manifest>` | Declares the module's `tier`, `requires` and entry point |
| `scripts/build-release.sh` | Stack-neutral release builder (below). Generated from `templates/tiered-common/` |
| `scripts/release-stack.sh` | The stack's hooks for the release builder |
| `release.exclude` | Internal paths never shipped: `docs/`, `notes/`, `.github/`, AI-agent files, release tooling |
| CI workflow | Runs the suite once per tier, the arch test, and a release smoke build per lower tier |

## Release build

`scripts/build-release.sh <tier> <version> [--ref <git-ref>]`

1. `git archive <ref>` into a temp folder. **No git history**, because history contains every tier.
2. Delete the module folders above `<tier>`, then every path in `release.exclude`.
3. Write `<PREFIX>_TIER=<tier>` into `.env.example`.
4. **Leak check:** grep the remaining files for the removed modules' paths and the stack's leak
   patterns (namespaces, view names). Any hit fails the build and names the file.
5. With `<PREFIX>_TIER=<tier>`, run the stack's `stack_install_dev`, then `stack_test`, then
   `stack_install_prod`. The stripped build's own test suite must pass, which proves core and
   the remaining modules stand alone.
6. `git init` a fresh repo with one commit, `<Project> v<version> (<Tier>)`, and zip it to
   `../<project>-releases/` (or `$RELEASE_OUT`).
7. Print the SHA-256. If a local `notes/` folder exists, append the release to
   `notes/releases.md` as the handover record.

The client (or their next developer) gets the fresh repo. They never get the development repo.

### `scripts/release-stack.sh` hooks

| Function | Must |
| --- | --- |
| `stack_module_dir <tier>` | Print the module's folder, relative to the repo root |
| `stack_leak_patterns <tier>` | Print extended regexes, one per line, that must not appear once the module is removed |
| `stack_install_dev` | Install dependencies, including dev/test ones |
| `stack_test` | Run the full test suite; fail on any failure |
| `stack_install_prod` | Reinstall for production and remove dev-only artefacts |

### Upgrading a client later

Build a release of the higher tier at the version they run (or the latest). Give them the new
module folder(s) plus any core changes as a new commit on their repo. They then run the
migrations and set `<PREFIX>_TIER`. If someone else has changed their code meanwhile, it is a
normal merge.

## Choosing a prefix

The scaffolders refuse prefixes that already mean something, such as `app`, `module`, `tier`,
`feature`, `user`, and `tenant`. `tenant` is the reason the check exists: in a rental app it
means a renter, and in Laravel packages it means multi-tenancy, so `TENANT_TIER` reads two ways.
Use an abbreviation of the product name (`tms`, `salon`).

## AI agents

Tiered projects get the same commit review gate as every generated project (`AGENTS.md`,
`CLAUDE.md`, `.claude/settings.json`, `scripts/propose-commit.sh`). The Claude Code settings
also ask before `scripts/build-release.sh` runs, since a release is something a client receives.

## Per-stack implementation

| Concept | Laravel | Django | Node.js (Express + TS) |
| --- | --- | --- | --- |
| Module folder | `modules/Standard/` (PSR-4 `Modules\Standard\`) | `modules/standard/` (Django app) | `modules/standard/` (plain folder; one `package.json`) |
| Manifest | `module.php` | `module.py` (`TIER`, `REQUIRES`, `APP`) | `module.json` (`tier`, `requires`, `entry`) |
| Loader | `App\Support\Modules` registers providers | settings build `INSTALLED_APPS` and URLs from modules on disk | `Modules` in `src/support/modules.ts` imports each entry and mounts its router at `/<tier>` |
| Feature switches | Laravel Pennant | `core.features` registry, overrides stored as django-waffle switches | `Features` registry, overrides in a `features` table |
| Permissions | `Permission` enum → Gates, `<x-can>` | `Permission` enum → `User.has_perm`, Django `can` template tag | `Permissions` registry → `requirePermission()` and a `can()` view helper |
| Arch test | PHPUnit scan for `Modules\` | pytest scan for `modules` imports, tier URL namespaces and template folders | vitest scan for `modules/` imports and tier view folders |
| Scaffolder | `setup_laravel_tiered_project.sh` | `setup_django_tiered_project.sh` | `setup_node_tiered_project.sh` |

**Django note:** a Django superuser normally passes every permission check. The generated
`User.has_perm` keeps tier permissions to feature + role even for superusers, lets Django's own
model permissions (`core.change_user`, used by the admin) work as usual, and denies anything else.

**Node note:** each module exports its migrations as plain objects, and core hands only the
loaded modules' migrations to Knex, so a lower-tier database never gets higher-tier tables.
Sessions are stored in the app's database and forms carry a CSRF token.

Shared shell helpers for the scaffolders are in `scripts/common/tiered.sh`. Run
`./tests/test_tiered_common.sh` to check the helpers and the release builder against a stub stack.
