# AFMBridge Production Deployment Guide

This guide covers deploying AFMBridge in production environments.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Deployment Options](#deployment-options)
  - [Docker Deployment](#docker-deployment)
  - [systemd Service](#systemd-service)
  - [Bare Binary Deployment](#bare-binary-deployment)
- [Configuration](#configuration)
- [Security](#security)
- [Monitoring](#monitoring)
- [Performance Tuning](#performance-tuning)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements

- **macOS 26.0+** (Sequoia with Apple Intelligence)
- **Apple Silicon** (M1, M2, M3, M4 series)
- **8GB RAM minimum** (16GB+ recommended for production)
- **10GB free disk space** for model downloads

### Network Requirements

- **Port 8080** (default, configurable)
- **Outbound HTTPS** for initial model downloads (if models not cached)

## Deployment Options

### Docker Deployment

#### Building the Image

```bash
# Clone repository
git clone https://github.com/kolohelios/afmbridge.git
cd afmbridge

# Build Docker image
docker build -t afmbridge:latest .
```

#### Running with Docker

```bash
# Basic deployment
docker run -d \
  --name afmbridge \
  -p 8080:8080 \
  afmbridge:latest

# With API key authentication
docker run -d \
  --name afmbridge \
  -p 8080:8080 \
  -e API_KEY=your-secret-key-here \
  -e LOG_LEVEL=info \
  afmbridge:latest

# With custom configuration
docker run -d \
  --name afmbridge \
  -p 8080:8080 \
  -e HOST=0.0.0.0 \
  -e PORT=8080 \
  -e MAX_TOKENS=2048 \
  -e LOG_LEVEL=info \
  -e API_KEY=your-secret-key-here \
  afmbridge:latest
```

#### Using Docker Compose

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  afmbridge:
    image: afmbridge:latest
    container_name: afmbridge
    ports:
      - "8080:8080"
    environment:
      - HOST=0.0.0.0
      - PORT=8080
      - MAX_TOKENS=2048
      - LOG_LEVEL=info
      - API_KEY=${AFM_API_KEY}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

Run with:

```bash
export AFM_API_KEY=your-secret-key
docker-compose up -d
```

### systemd Service

For production deployments on macOS servers or Linux (with Rosetta), use systemd for process management.

#### Service Configuration

Create `/etc/systemd/system/afmbridge.service`:

```ini
[Unit]
Description=AFMBridge - Apple Foundation Models REST API
After=network.target
Documentation=https://github.com/kolohelios/afmbridge

[Service]
Type=simple
User=afmbridge
Group=afmbridge
WorkingDirectory=/opt/afmbridge
ExecStart=/opt/afmbridge/AFMBridge serve
Restart=on-failure
RestartSec=10s

# Environment variables
Environment="HOST=0.0.0.0"
Environment="PORT=8080"
Environment="MAX_TOKENS=2048"
Environment="LOG_LEVEL=info"
EnvironmentFile=-/etc/afmbridge/config.env

# Security hardening
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/afmbridge

# Resource limits
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
```

#### Setup Steps

```bash
# Create service user
sudo useradd -r -s /bin/false afmbridge

# Create directories
sudo mkdir -p /opt/afmbridge
sudo mkdir -p /etc/afmbridge
sudo mkdir -p /var/lib/afmbridge

# Download and install binary
curl -L -o afmbridge.tar.gz \
  https://github.com/kolohelios/afmbridge/releases/latest/download/afmbridge-macos-latest.tar.gz
sudo tar -xzf afmbridge.tar.gz -C /opt/afmbridge
sudo chmod +x /opt/afmbridge/AFMBridge

# Set ownership
sudo chown -R afmbridge:afmbridge /opt/afmbridge
sudo chown -R afmbridge:afmbridge /var/lib/afmbridge

# Create environment file (optional)
sudo cat > /etc/afmbridge/config.env << EOF
API_KEY=your-secret-key-here
LOG_LEVEL=info
EOF
sudo chmod 600 /etc/afmbridge/config.env
sudo chown afmbridge:afmbridge /etc/afmbridge/config.env

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable afmbridge
sudo systemctl start afmbridge

# Check status
sudo systemctl status afmbridge
```

#### Managing the Service

```bash
# Start service
sudo systemctl start afmbridge

# Stop service
sudo systemctl stop afmbridge

# Restart service
sudo systemctl restart afmbridge

# View logs
sudo journalctl -u afmbridge -f

# View last 100 log lines
sudo journalctl -u afmbridge -n 100
```

### Bare Binary Deployment

For simple deployments without Docker or systemd.

```bash
# Download latest release
VERSION=v0.1.0-beta.7
curl -L -o afmbridge.tar.gz \
  https://github.com/kolohelios/afmbridge/releases/download/${VERSION}/afmbridge-macos-${VERSION}.tar.gz

# Extract
tar -xzf afmbridge.tar.gz

# Run with environment variables
HOST=0.0.0.0 \
PORT=8080 \
MAX_TOKENS=2048 \
LOG_LEVEL=info \
API_KEY=your-secret-key \
./AFMBridge serve
```

## Configuration

### Environment Variables

| Variable     | Default     | Description                              |
| ------------ | ----------- | ---------------------------------------- |
| `HOST`       | `127.0.0.1` | Bind address (use `0.0.0.0` for Docker) |
| `PORT`       | `8080`      | HTTP port                                |
| `MAX_TOKENS` | `1024`      | Maximum tokens per request               |
| `LOG_LEVEL`  | `info`      | Log level: trace, debug, info, warning, error |
| `API_KEY`    | (none)      | API key for authentication (optional)    |

### Configuration Best Practices

#### Development

```bash
HOST=127.0.0.1
PORT=8080
LOG_LEVEL=debug
# No API_KEY for local development
```

#### Production

```bash
HOST=0.0.0.0
PORT=8080
MAX_TOKENS=2048
LOG_LEVEL=info
API_KEY=<strong-random-key>  # REQUIRED in production
```

**Generate a strong API key:**

```bash
# macOS
openssl rand -base64 32

# Linux
head -c 32 /dev/urandom | base64
```

## Security

### Authentication

**Always enable API key authentication in production:**

```bash
# Generate strong key
API_KEY=$(openssl rand -base64 32)
echo "Your API key: $API_KEY"

# Set in environment
export API_KEY=$API_KEY
./AFMBridge serve
```

**Client usage:**

```bash
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-4o", "messages": [{"role": "user", "content": "Hello"}]}'
```

### Network Security

#### Reverse Proxy (Recommended)

Use nginx or Caddy as a reverse proxy for HTTPS:

**nginx configuration:**

```nginx
server {
    listen 443 ssl http2;
    server_name api.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # For SSE streaming
        proxy_buffering off;
        proxy_cache off;
        proxy_set_header Connection '';
        proxy_http_version 1.1;
        chunked_transfer_encoding off;
    }
}
```

**Caddy configuration:**

```caddyfile
api.example.com {
    reverse_proxy localhost:8080 {
        flush_interval -1
    }
}
```

#### Firewall

```bash
# macOS firewall (pf)
# Allow only local connections if using reverse proxy
echo "block in proto tcp from any to any port 8080" | sudo pfctl -f -

# Or use built-in Application Firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /opt/afmbridge/AFMBridge
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /opt/afmbridge/AFMBridge
```

### Data Privacy

AFMBridge uses Apple's FoundationModels framework, which provides:

- **On-device inference** - All processing happens locally
- **No data transmission** - Requests never leave your Mac
- **Privacy by design** - Apple Intelligence privacy guarantees
- **Offline capable** - Works without internet (after model download)

**Important:** While inference is local, ensure your API keys and environment variables are kept secure.

## Monitoring

### Health Checks

```bash
# Basic health check
curl http://localhost:8080/health
# Returns: OK (200 status)

# Automated health monitoring
while true; do
  if curl -f http://localhost:8080/health >/dev/null 2>&1; then
    echo "$(date): Service healthy"
  else
    echo "$(date): Service unhealthy"
    # Alert or restart service
  fi
  sleep 30
done
```

### Logging

AFMBridge uses structured logging via Vapor's logging system.

#### Log Levels

- **trace** - Very detailed debugging (not recommended for production)
- **debug** - Debugging information
- **info** - General informational messages (recommended for production)
- **warning** - Warning messages
- **error** - Error messages

#### Log Format

```text
2026-02-27T13:00:00-0800 info : [request-id] POST /v1/chat/completions
2026-02-27T13:00:00-0800 info : [request-id] Response sent [200] (234ms)
```

#### Viewing Logs

**Docker:**

```bash
docker logs -f afmbridge
```

**systemd:**

```bash
journalctl -u afmbridge -f
```

**Bare binary:**

Logs are written to stdout/stderr. Redirect to file:

```bash
./AFMBridge serve 2>&1 | tee /var/log/afmbridge.log
```

### Metrics

AFMBridge includes built-in metrics middleware that logs:

- Request method and path
- Response status code
- Request duration (ms)
- Timestamp

**Example metrics log:**

```text
2026-02-27T13:00:00-0800 info : Request: POST /v1/chat/completions
2026-02-27T13:00:01-0800 info : Response: 200 OK (duration: 234ms)
```

#### Integration with Monitoring Tools

**Export to Prometheus:**

Use a log scraper like `promtail` or `fluentd` to parse logs and export to Prometheus.

**Example promtail config:**

```yaml
scrape_configs:
  - job_name: afmbridge
    static_configs:
      - targets:
          - localhost
        labels:
          job: afmbridge
          __path__: /var/log/afmbridge.log
```

## Performance Tuning

### Model Performance

AFMBridge uses Apple's on-device FoundationModels framework. Performance depends on:

- **Apple Silicon generation** - M4 > M3 > M2 > M1
- **Unified memory** - More RAM = faster inference
- **Model size** - Larger models are slower but more capable
- **Max tokens** - Lower `MAX_TOKENS` = faster responses

### Concurrency

Vapor handles concurrent requests automatically. AFMBridge can handle:

- **Streaming requests** - Multiple concurrent SSE streams
- **Non-streaming requests** - High throughput for simple completions
- **Tool calling** - Multiple concurrent tool calling sessions

**Recommended limits:**

- **Max concurrent requests:** 10-20 (depends on RAM and CPU)
- **Request timeout:** 120s (2 minutes, configurable in Vapor)

### Memory Management

**Recommended memory allocation:**

- **8GB RAM:** 2-4 concurrent requests
- **16GB RAM:** 5-10 concurrent requests
- **32GB+ RAM:** 10-20 concurrent requests

**Monitor memory usage:**

```bash
# macOS
top -pid $(pgrep AFMBridge)

# Or use Activity Monitor GUI
```

## Troubleshooting

### Common Issues

#### Service Won't Start

**Symptom:** AFMBridge exits immediately after starting

**Diagnosis:**

```bash
# Check logs
journalctl -u afmbridge -n 50

# Or run manually to see errors
./AFMBridge serve
```

**Common causes:**

1. **Port already in use:**
   ```bash
   # Check what's using port 8080
   lsof -i :8080

   # Solution: Change PORT environment variable
   PORT=8081 ./AFMBridge serve
   ```

2. **Permission denied:**
   ```bash
   # Solution: Check file permissions
   chmod +x AFMBridge
   ```

3. **Missing FoundationModels framework:**
   ```bash
   # Solution: Ensure macOS 26.0+ with Apple Intelligence enabled
   sw_vers
   ```

#### Requests Timeout

**Symptom:** Requests take too long or timeout

**Diagnosis:**

```bash
# Test basic request
time curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-4o", "messages": [{"role": "user", "content": "Hi"}], "max_tokens": 10}'
```

**Solutions:**

1. **Reduce max_tokens:**
   ```bash
   MAX_TOKENS=512 ./AFMBridge serve
   ```

2. **Check system resources:**
   ```bash
   # CPU and memory usage
   top -pid $(pgrep AFMBridge)
   ```

3. **Reduce concurrent requests:**
   Limit clients to 1-2 concurrent requests per instance

#### Authentication Errors

**Symptom:** 401 Unauthorized errors

**Diagnosis:**

```bash
# Check if API key is set
env | grep API_KEY

# Test with explicit API key
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Authorization: Bearer test-key" \
  -H "Content-Type: application/json" \
  -d '{"model": "gpt-4o", "messages": [{"role": "user", "content": "Hi"}]}'
```

**Solutions:**

1. **API key mismatch:**
   - Ensure client uses `Authorization: Bearer <API_KEY>` header
   - Verify API_KEY environment variable matches

2. **Missing API key:**
   - If API_KEY is not set, authentication is disabled
   - For production, always set API_KEY

#### Memory Leaks

**Symptom:** Memory usage grows over time

**Diagnosis:**

```bash
# Monitor memory over time
while true; do
  ps -o rss,vsz -p $(pgrep AFMBridge)
  sleep 60
done
```

**Solutions:**

1. **Restart service periodically:**
   ```bash
   # Add to crontab for daily restart
   0 3 * * * systemctl restart afmbridge
   ```

2. **Limit max tokens:**
   ```bash
   MAX_TOKENS=1024 ./AFMBridge serve
   ```

### Debug Mode

Enable detailed logging for troubleshooting:

```bash
LOG_LEVEL=debug ./AFMBridge serve
```

**Debug logs include:**

- Request/response bodies
- Internal service calls
- Error stack traces
- Performance metrics

**Warning:** Debug logging can be verbose. Only use for troubleshooting.

### Getting Help

If you encounter issues:

1. **Check documentation:**
   - [README.md](README.md) - General usage
   - [API.md](API.md) - API reference
   - [CONTRIBUTING.md](CONTRIBUTING.md) - Development guide

2. **Search existing issues:**
   - [GitHub Issues](https://github.com/kolohelios/afmbridge/issues)

3. **Report a bug:**
   - Create a new issue with:
     - macOS version (`sw_vers`)
     - Apple Silicon model
     - AFMBridge version
     - Full error logs
     - Steps to reproduce

## Best Practices Checklist

- [ ] **Enable API key authentication** (`API_KEY` set)
- [ ] **Use HTTPS** (reverse proxy with SSL/TLS)
- [ ] **Bind to 0.0.0.0** (for container deployments)
- [ ] **Set LOG_LEVEL=info** (production logging)
- [ ] **Configure health checks** (monitoring endpoint)
- [ ] **Set resource limits** (systemd or Docker)
- [ ] **Monitor logs** (structured logging)
- [ ] **Regular restarts** (if memory leaks observed)
- [ ] **Firewall rules** (restrict access)
- [ ] **Backup configuration** (environment variables)

## Production Deployment Checklist

Before deploying to production:

- [ ] Test with realistic workload
- [ ] Verify API key authentication works
- [ ] Configure HTTPS reverse proxy
- [ ] Set up health check monitoring
- [ ] Configure log aggregation
- [ ] Document API key rotation process
- [ ] Set up alerting for downtime
- [ ] Test failover/restart procedures
- [ ] Verify resource limits are appropriate
- [ ] Create runbook for common issues

## Next Steps

- Review [API.md](API.md) for complete API documentation
- Check [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines
- See [README.md](README.md) for quick start guide

---

**Need help?** Open an issue on [GitHub](https://github.com/kolohelios/afmbridge/issues)
