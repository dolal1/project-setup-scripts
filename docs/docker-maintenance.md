# 🐳 Docker Maintenance Guide

How to reclaim disk space and rebuild containers **without losing your database** and
**without the rebuild temporarily doubling your disk usage**.

This applies to any project created by these scripts. They ship a `docker-compose.yml`
that declares four **named** volumes — `postgres_data`, `redis_data`, `node_modules`, and
`backend_venv` — which matters for what the cleanup commands below can and cannot reach.

---

## ⚠️ Read This First: The `LINKS 0` Trap

When your containers are stopped, **every** volume reports zero links — including your
database:

```bash
$ docker compose down
$ docker system df -v

VOLUME NAME                   LINKS     SIZE
myproject_postgres_data       0         165.3MB   # <-- your database!
otherproject_pgdata           0         66.17MB   # <-- another project's database!
```

`LINKS 0` means "no *container* currently references this", **not** "this is empty or
disposable". Any prune that removes unused *named* volumes will delete these.

**Never run these while containers are down** (or ever, on a multi-project machine):

```bash
docker volume prune -a           # ❌ deletes named volumes = your DB
docker system prune -a --volumes # ❌ same, plus every other project's DB
docker volume prune --all        # ❌ same as -a
```

On a machine with several projects checked out, one `-a` volume prune wipes the
databases of **all** of them at once. There is no undo.

---

## ✅ What Each Prune Command Actually Removes

| Command | Removes | Touches named volumes? | Safe with DB present |
| --- | --- | --- | --- |
| `docker volume prune` | Anonymous volumes only | **No** | ✅ Yes |
| `docker volume prune -a` | Anonymous **+ named** volumes | **Yes** | ❌ **No** |
| `docker image prune` | Dangling (untagged) layers | No | ✅ Yes |
| `docker image prune -a` | Every image not used by a container | No | ⚠️ Forces re-pull of base images |
| `docker builder prune` | Unused build cache | No | ✅ Yes |
| `docker builder prune -a` | **All** build cache | No | ⚠️ Next build is from scratch |
| `docker system prune` | Stopped containers, dangling images, unused networks + cache | No | ✅ Yes |
| `docker system prune --volumes` | All of the above **+ named volumes** | **Yes** | ❌ **No** |

The key line: **plain `docker volume prune` removes only anonymous volumes.** Verify on
your own Docker version, since this default changed in Docker 23.0:

```bash
docker volume prune --help
# -a, --all   Remove all unused volumes, not just anonymous ones
#             ^ if this flag exists, the bare command is anonymous-only and safe
```

---

## 🔁 Rebuilding After a `git pull`

### Why the rebuild doubles your disk usage

`docker compose build` writes the new image layers **while the old images still exist**.
The old ones only become dangling once the new build finishes and takes over the tag. So
during the build you are holding both copies — on a multi-GB Django + Node image, that is
easily 10–20 GB of transient usage.

**Pruning first does not remove that peak.** `docker image prune` only drops *dangling*
layers, and the image you are about to replace is still tagged, so it is not a candidate.
What the pre-build prune buys you is headroom: it clears images orphaned by *earlier*
rebuilds plus unused build cache, which is usually the larger number on a machine that
has not been cleaned in a while. The peak itself is inherent to the rebuild.

If you genuinely cannot fit both copies at once, remove the current image by name first
(`docker rmi <project>-backend`) and accept a from-scratch rebuild — you trade the disk
peak for build time. Otherwise use the sequence below: prune before for headroom, prune
after to collect what the rebuild just orphaned.

### The sequence

```bash
# 1. Stop containers — note: NO -v flag, that would delete named volumes
docker compose down --remove-orphans

# 2. Reclaim anonymous volumes. On a project from these scripts this is usually a
#    no-op (all four volumes are named) — it catches strays left by `docker compose
#    run` or ad-hoc `docker run`. Safe either way: it never touches postgres_data.
docker volume prune -f

# 3. Drop image layers orphaned by EARLIER rebuilds (not the one you are about to
#    replace — that image is still tagged). This is the step that frees real space.
docker image prune -f

# 4. Drop unreferenced build cache. Some cache reuse may be lost, but the rebuild is
#    still far faster than --no-cache.
docker builder prune -f

# 5. Rebuild — expect a temporary peak holding both image copies (see above)
docker compose build

# 6. Start up
docker compose up -d

# 7. Sweep the images the rebuild just orphaned
docker image prune -f
```

### Verify before and after

```bash
docker system df                              # totals + reclaimable
docker volume ls | grep -E "postgres|pgdata"  # confirm the DB survived
docker compose exec postgres pg_isready       # confirm it still answers
```

---

## 📦 Where the Space Actually Goes

Run this to see the breakdown before deciding what to prune:

```bash
docker system df -v          # can take 1-2 minutes on a large install
```

### In a project from these scripts

All four volumes are named, so they are **reused** across rebuilds rather than duplicated.
They grow, but they do not multiply. What accumulates per rebuild is:

| Grows every rebuild | Reclaim with |
| --- | --- |
| Images orphaned when the new build takes the tag | `docker image prune -f` |
| Build cache | `docker builder prune -f` |
| `node_modules` / `backend_venv` contents | nothing automatic — see below |

So on these projects the routine cleanup is really an *image and cache* cleanup.
`docker volume prune` is worth running for hygiene, but do not expect it to move the
number — it only removes anonymous volumes, and this compose file creates none.

### The stale `node_modules` volume

`node_modules:/app/node_modules` shadows whatever the image has at that path. The volume
is populated from the image **once**, when it is first created, and never refreshed. A
rebuild that installs new dependencies therefore has no effect on the running container —
the old volume is still mounted over them.

Symptoms are missing or wrong-version packages after a `git pull` that touched
`package.json`, and lockfile/`node_modules` mismatch errors. The fix is to delete that one
volume **by name** and let the next `up` repopulate it from the image:

```bash
docker compose down
docker volume rm "$(basename "$PWD")_node_modules"   # safe: rebuilt from the image
docker compose up -d
```

Note that `backend_venv` behaves the same way, but the generated backend `Dockerfile`
installs Python packages system-wide rather than into `${VENV_NAME}`, so that volume
starts empty and stays empty. Deleting it changes nothing.

### When volumes *are* the problem: other project layouts

Volume pileup is real, just not on this layout. It shows up when a compose file uses
target-only mounts, which have no `source:` and so create a fresh **anonymous** volume
every time the container is recreated:

```yaml
volumes:
  - type: volume
    target: /workspace/node_modules        # no source: = anonymous volume
  - type: volume
    target: /workspace/apps/app/node_modules
```

Each `docker compose up` leaves the previous set behind, orphaned but never collected —
one full `node_modules` per rebuild. From a pnpm monorepo that had been rebuilt for
months:

```text
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          10        1         17.43GB   12.65GB (72%)
Containers      1         0         16.38kB   16.38kB (100%)
Local Volumes   71        0         50.22GB   50.22GB (100%)
Build Cache     58        0         19.68GB   4.76GB
```

**50 GB in volumes, across 63 anonymous ones.** Here plain `docker volume prune` (no `-a`)
is exactly the right tool, and the containers recreate what they need on the next `up`.
It also clears the stale-dependency errors described above — pnpm's
`ERR_PNPM_VERIFY_DEPS_BEFORE_RUN` is the usual one.

---

## 🔍 Finding Orphaned Named Volumes

After a repo restructure, named volumes from the old layout linger forever — they are
named, so no safe prune touches them. Compare what exists against what the current
compose file declares:

```bash
# What compose expects now (prints unprefixed names)
docker compose config --volumes

# The prefix Compose actually uses: the project name, lowercased with invalid
# characters stripped — NOT always the raw directory name. Confirm with `docker compose ls`.
PROJECT=${COMPOSE_PROJECT_NAME:-$(basename "$PWD" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]_-')}

# What actually exists
docker volume ls --filter "name=${PROJECT}_"
```

Anything in the second list but not the first is an orphan. Remove those **by name**,
never with `-a`:

```bash
docker volume rm myproject_old_node_modules
```

---

## 🧹 Deeper Cleanups

Only when you need the space badly enough to pay for it later:

```bash
# Remove a specific large stale image (find candidates via docker system df -v)
docker rmi some-old-build:latest

# Nuke ALL build cache — next build recompiles everything, expect 10+ minutes
docker builder prune -a -f

# Remove every image not used by a running container — forces re-pull of
# postgres, redis, etc. on next up
docker image prune -a -f
```

---

## 💾 Backing Up the Database First

If you must run a volume operation you are unsure about, dump the database first. This
is cheap and turns an irreversible mistake into an inconvenience:

```bash
# Dump (container must be running). User/database default to postgres / myapp_db
# in the generated .env — adjust if you changed DB_USER or DB_NAME.
BACKUP="backup_$(date +%F).sql"
docker compose exec -T postgres pg_dump -U postgres myapp_db > "$BACKUP"

# Restore into a fresh volume
docker compose up -d postgres
docker compose exec -T postgres psql -U postgres myapp_db < "$BACKUP"
```

Or copy the whole volume without starting the app:

```bash
docker run --rm \
  -v myproject_postgres_data:/data:ro \
  -v "$PWD":/backup \
  alpine tar czf /backup/postgres_data.tar.gz -C /data .
```

---

## 📋 Quick Reference

```bash
# Safe routine cleanup — run any time, keeps all databases.
# On these projects the last two lines are what actually free space.
docker compose down --remove-orphans
docker volume prune -f
docker image prune -f
docker builder prune -f

# Rebuild after a git pull (run the block above FIRST, for headroom)
docker compose build && docker compose up -d && docker image prune -f

# Dependencies changed? Drop the shadowing node_modules volume too, before `up`
docker volume rm "$(basename "$PWD")_node_modules"

# Emergency: check what you are about to lose
docker system df -v | sed -n '/Local Volumes/,$p'
```

---

## 📚 Related

- [Troubleshooting Guide](troubleshooting.md) — container build failures, port conflicts,
  permission issues
- [Django + TypeScript Setup Guide](django-typescript-setup.md)
- [Docker prune documentation](https://docs.docker.com/engine/manage-resources/pruning/)
