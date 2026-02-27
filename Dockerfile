# Multi-stage Dockerfile for AFMBridge
# Stage 1: Build with Swift
# Stage 2: Runtime image

# Stage 1: Builder
FROM swift:6.0.3-noble AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    libsqlite3-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy source
WORKDIR /build
COPY . .

# Build with Swift
RUN swift build -c release --static-swift-stdlib

# Stage 2: Runtime
FROM debian:bookworm-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libicu72 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# Copy binary from builder
COPY --from=builder /build/.build/release/AFMBridge /usr/local/bin/AFMBridge

# Set environment variables
ENV HOST=0.0.0.0
ENV PORT=8080

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run as non-root user
RUN useradd -m -u 1000 afmbridge
USER afmbridge

# Start server
ENTRYPOINT ["/usr/local/bin/AFMBridge"]
