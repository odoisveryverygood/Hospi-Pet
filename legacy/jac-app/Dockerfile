FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV PATH="/root/.local/bin:${PATH}"

COPY . .

RUN curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh \
    | bash -s -- --version 0.34.7 \
    && jac install

CMD ["sh", "-c", "jac start main.jac --no-client --no-dev --port ${PORT:-8000}"]
