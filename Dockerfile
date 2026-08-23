ARG ELIXIR_VERSION=1.17.3
ARG OTP_VERSION=27.2.4
ARG DEBIAN_VERSION=bookworm-20260803-slim

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION} AS build

RUN apt-get update -y && apt-get install -y --no-install-recommends build-essential git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod && mix deps.compile

COPY config config
COPY lib lib
COPY priv priv
COPY assets assets

RUN mix assets.deploy && mix compile && mix release

FROM debian:${DEBIAN_VERSION} AS app

RUN apt-get update -y && apt-get install -y --no-install-recommends \
      ca-certificates \
      chromium \
      curl \
      libncurses5 \
      libstdc++6 \
      openssl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN groupadd --gid 1000 tracms && \
    useradd --uid 1000 --gid tracms --create-home --shell /bin/false tracms

COPY --from=build --chown=tracms:tracms /app/_build/prod/rel/tracms ./

USER tracms

ENV HOME=/app \
    PHX_SERVER=true

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl --fail --silent http://127.0.0.1:4000/health || exit 1

CMD ["/bin/sh", "-c", "/app/bin/migrate && exec /app/bin/server"]
