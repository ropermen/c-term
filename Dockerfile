# Stage 1: Build Flutter web
FROM ghcr.io/cirruslabs/flutter:3.27.3 AS flutter-build

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release

# Stage 2: Build RDP proxy (Rust)
FROM rust:bookworm AS rust-build

WORKDIR /proxy
COPY rdp-proxy/Cargo.toml rdp-proxy/Cargo.lock* ./
RUN mkdir src && echo 'fn main(){}' > src/main.rs && cargo build --release 2>/dev/null || true && rm -rf src target/release/rdp-proxy target/release/deps/rdp_proxy*
COPY rdp-proxy/src ./src
RUN cargo build --release

# Stage 3: Serve with nginx + rdp-proxy
FROM nginx:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    supervisor libssl3 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY nginx.container.conf /etc/nginx/conf.d/default.conf
COPY --from=flutter-build /app/build/web /usr/share/nginx/html

# Copy RDP proxy binary
COPY --from=rust-build /proxy/target/release/rdp-proxy /usr/local/bin/rdp-proxy

# Supervisor config to run both nginx and rdp-proxy
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN mkdir -p /data
VOLUME ["/data"]

EXPOSE 18884

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
