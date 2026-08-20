# switchyard-bundle

A single-container setup for [NeMo Switchyard](https://github.com/NVIDIA-NeMo/Switchyard).
It serves an OpenAI-compatible endpoint on `127.0.0.1:4100` and picks a model
per request before relaying to Fireworks.

No client is bundled and none is assumed. Anything that speaks the OpenAI API
can point at the port, and the client's own configuration stays outside this
repo.

## Routes

Defined in `routes.toml`. A route's `id` is the model name the client sees.

| id | Behaviour |
|---|---|
| `auto` | A judge estimates every turn whether the weak tier suffices |
| `auto-esc` | Always starts weak, latches to strong once trouble is confirmed twice |
| `weak-only` | Pinned to DeepSeek V4 Flash |
| `strong-only` | Pinned to DeepSeek V4 Pro |
| `k3-only` | Pinned to Kimi K3, for image input |

`auto-esc` differs from `auto` in more than how it escalates. Responses are
buffered until it latches, so streaming is not real; the confirming turn is
billed on both tiers; and once raised it does not come back down for the rest of
the session.

## Running it

Pass the Fireworks API key through the environment. The secret store is
deliberately not fixed here — `op run`, a `.env` file, direnv, anything that can
put it in the environment will do. Starting without it fails while compose is
still parsing.

```shell
$ export FIREWORKS_API_KEY=fw_...
$ docker compose up -d
$ curl -s http://127.0.0.1:4100/health
{"status":"ok"}
```

Stop it with `docker compose down`. Because of `restart: unless-stopped`, Docker
brings it back until you stop it explicitly.

## Changing the configuration

`routes.toml` is bind-mounted, so editing routes needs no image rebuild. The
TOML surface is `deny_unknown_fields` though, so a mistyped key fails at
startup. Validate before restarting:

```shell
$ docker compose run --rm switchyard --config /app/routes.toml --dry-run
```

## Looking at what it does

```shell
$ curl -s http://127.0.0.1:4100/v1/models | jq .   # routes being served
$ curl -s http://127.0.0.1:4100/v1/stats  | jq .   # aggregate routing counts
$ docker compose logs -f                           # server log
```

Per-request decisions land in `routing.jsonl` on a named volume, so they survive
image rebuilds and `--force-recreate`:

```shell
$ docker compose exec switchyard tail -f /app/logs/routing.jsonl
```

## Versions

`SWITCHYARD_VERSION` in the `Dockerfile` pins a crates.io release. Do not follow
`main` — it carries the next development cycle's internal Rust API churn. When
bumping it, check the config surface with `--dry-run` first.
