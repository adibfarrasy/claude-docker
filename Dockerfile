# ---------- Rust tools: rtk + allium-cli ----------
# Built from source against bookworm's glibc 2.36 (release binaries want 2.39).
ARG RTK_VERSION=v0.35.0
ARG ALLIUM_VERSION=3.0.5

FROM rust:bookworm AS rust-tools
ARG RTK_VERSION
ARG ALLIUM_VERSION
RUN cargo install --locked --git https://github.com/rtk-ai/rtk --tag "${RTK_VERSION}" rtk
RUN cargo install --locked --version "${ALLIUM_VERSION}" allium-cli

# ---------- Go tools: gopls ----------
FROM golang:bookworm AS go-tools
ENV GOBIN=/out
RUN mkdir -p /out && go install golang.org/x/tools/gopls@latest

# ---------- Node + typescript-language-server ----------
# Using the official node image avoids Debian's flaky arm64 bookworm-updates repo.
FROM node:20-bookworm-slim AS node-tools
RUN npm install -g --prefix=/out typescript typescript-language-server

# ---------- Final image ----------
FROM vibepod/claude:latest

# Node runtime + typescript-language-server from the node-tools stage.
COPY --from=node-tools /usr/local/bin/node /usr/local/bin/node
COPY --from=node-tools /out/lib/node_modules /usr/local/lib/node_modules
RUN ln -sf /usr/local/lib/node_modules/typescript-language-server/lib/cli.mjs /usr/local/bin/typescript-language-server \
 && ln -sf /usr/local/lib/node_modules/typescript/bin/tsc /usr/local/bin/tsc \
 && ln -sf /usr/local/lib/node_modules/typescript/bin/tsserver /usr/local/bin/tsserver \
 && node --version && typescript-language-server --version

# rust-analyzer: standalone prebuilt binary from upstream releases.
ARG RUST_ANALYZER_VERSION=2026-04-20
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      arm64)  target="aarch64-unknown-linux-gnu" ;; \
      amd64)  target="x86_64-unknown-linux-gnu" ;; \
      *) echo "unsupported arch: $arch" >&2; exit 1 ;; \
    esac; \
    url="https://github.com/rust-lang/rust-analyzer/releases/download/${RUST_ANALYZER_VERSION}/rust-analyzer-${target}.gz"; \
    curl -fsSL "$url" | gunzip > /usr/local/bin/rust-analyzer; \
    chmod 755 /usr/local/bin/rust-analyzer; \
    rust-analyzer --version

# Binaries from builder stages
COPY --from=rust-tools /usr/local/cargo/bin/rtk /usr/local/bin/rtk
COPY --from=rust-tools /usr/local/cargo/bin/allium /usr/local/bin/allium
COPY --from=go-tools /out/gopls /usr/local/bin/gopls
RUN chmod 755 /usr/local/bin/rtk /usr/local/bin/allium /usr/local/bin/gopls \
 && rtk --version && allium --version && gopls version

# Bake portable host config into /claude-defaults. The wrapper entrypoint
# seeds /claude from this on first run so a volume mount at /claude still
# works (first run into an empty volume populates it).
COPY staging/claude-defaults/ /claude-defaults/

COPY entrypoint-wrapper.sh /usr/local/bin/entrypoint-wrapper.sh
RUN chmod +x /usr/local/bin/entrypoint-wrapper.sh \
 && chmod -R a+rX /claude-defaults

ENTRYPOINT ["/usr/local/bin/entrypoint-wrapper.sh"]
CMD ["claude", "--dangerously-skip-permissions"]
