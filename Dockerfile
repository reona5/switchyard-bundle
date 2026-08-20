# Switchyard の native（Rust）サーバだけを載せたイメージ。
# 中身はルータ 1 プロセスだけで、クライアントは含めない。OpenAI 互換の口を
# 喋るものであれば何を繋いでもよく、繋ぐ側の設定はこのイメージの外側の話。

# --- builder: crates.io から switchyard-server を入れる。Python は一切使わない。
ARG RUST_VERSION=1.96.1
FROM rust:${RUST_VERSION}-bookworm AS builder

# main ではなくリリース版を固定する。main は次の開発サイクル（Rust 内部 API の
# 変更）を載せているので追うと未リリースのサーバを動かすことになる。
# TOML の設定面は deny_unknown_fields なので、上げたら必ず --dry-run で検証する。
ARG SWITCHYARD_VERSION=0.2.0

RUN cargo install --locked switchyard-server \
        --version "${SWITCHYARD_VERSION}" \
        --root /opt/out

# --- runtime: バイナリ 1 本だけを slim base に置く。
FROM debian:bookworm-slim

# ca-certificates は upstream への TLS 用、curl は compose の healthcheck 用。
RUN apt-get update \
    && apt-get install --no-install-recommends -y ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder \
    /opt/out/bin/switchyard-server \
    /usr/local/bin/switchyard-server

WORKDIR /app
# 既定の設定を焼き込んでおく。compose 側で同じパスに bind mount して上書きするので、
# ルート定義をいじるだけならイメージの再ビルドは要らない。
COPY routes.toml /app/routes.toml
# --routing-log-file の書き込み先。非 root で動かすため所有者を合わせる。
RUN mkdir -p /app/logs && chown 1000:1000 /app/logs
ENV HOME=/tmp
USER 1000:1000

EXPOSE 4100

ENTRYPOINT ["switchyard-server"]
CMD ["--config", "/app/routes.toml", "--host", "0.0.0.0", "--port", "4100"]
