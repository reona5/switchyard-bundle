# switchyard-bundle

[NeMo Switchyard](https://github.com/NVIDIA-NeMo/Switchyard) をコンテナ 1 つで
動かすための定義。OpenAI 互換のエンドポイントを `127.0.0.1:4100` に立て、
リクエストごとに呼び先のモデルを選んで Fireworks へ中継する。

クライアントは含めない。OpenAI 互換の口を喋るものなら何を繋いでもよく、
繋ぐ側の設定はこのリポジトリの外側で持つ。

## ルート

`routes.toml` で定義している。クライアントからはこの `id` がモデル名として見える。

| id | 中身 |
|---|---|
| `auto` | 毎ターン judge が weak で足りるかを見積もって振り分ける |
| `auto-esc` | 必ず weak で始まり、行き詰まりを 2 回続けて検出したら strong に固定する |
| `weak-only` | DeepSeek V4 Flash に固定 |
| `strong-only` | DeepSeek V4 Pro に固定 |
| `k3-only` | Kimi K3 に固定（画像を読ませたいとき） |

`auto` と `auto-esc` の違いは上げ方だけではない。`auto-esc` は固定されるまで応答が
バッファされるので真のストリーミングにならず、確定したターンでは両方の tier に
課金され、一度上がるとセッション中は下がらない。

## 使う

Fireworks の API キーを環境変数で渡す。秘密管理の道具はあえて固定していないので、
`op run` でも `.env` でも direnv でも、環境に入れられれば何でもよい。未設定のまま
起動すると compose の parse 時点で落ちる。

```shell
$ export FIREWORKS_API_KEY=fw_...
$ docker compose up -d
$ curl -s http://127.0.0.1:4100/health
{"status":"ok"}
```

止めるのは `docker compose down`。`restart: unless-stopped` を付けてあるので、
明示的に止めるまでは Docker が上げ直す。

## 設定を変える

`routes.toml` は compose から bind mount しているので、ルート定義をいじるだけなら
イメージの再ビルドは要らない。ただし TOML の設定面は `deny_unknown_fields` なので、
キー名を打ち間違えると起動時に落ちる。再起動する前に検証する。

```shell
$ docker compose run --rm switchyard --config /app/routes.toml --dry-run
```

## 様子を見る

```shell
$ curl -s http://127.0.0.1:4100/v1/models | jq .      # 配信中のルート
$ curl -s http://127.0.0.1:4100/v1/stats  | jq .      # 振り分けの集計
$ docker compose logs -f                              # サーバのログ
```

リクエスト単位の判断は named volume の `routing.jsonl` に落ちている。イメージを
再ビルドしても消えない。

```shell
$ docker compose exec switchyard tail -f /app/logs/routing.jsonl
```

## バージョン

`Dockerfile` の `SWITCHYARD_VERSION` は crates.io のリリース版を固定している。
main は次の開発サイクルの内部 API 変更を載せているので追わない。上げるときは
`--dry-run` で設定面の互換を確かめてから。

## 出典

構成は [himorishige/switchyard-opencode-bundle](https://github.com/himorishige/switchyard-opencode-bundle)
を下敷きにしている。`routes.toml` の閾値などの校正値もあちらの計測に基づくもので、
ここで測り直したものではない。
