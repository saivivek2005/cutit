# PeakCut: Production Docker image with Python, Node.js, FFmpeg, and yt-dlp
FROM python:3.11-slim

# Install system dependencies:
# - ffmpeg: audio/video processing and clip cutting
# - nodejs: JavaScript engine for yt-dlp signature extraction
# - ca-certificates: TLS verification for video streaming and downloads
# - bzip2 & curl: model decompression and container health checks
# - fonts-noto-core & fonts-noto-cjk: caption rendering support
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    nodejs \
    ca-certificates \
    bzip2 \
    curl \
    fonts-noto-core \
    fonts-noto-cjk \
 && rm -rf /var/lib/apt/lists/*

# Also provide Deno as an additional fast JS runtime for yt-dlp
COPY --from=denoland/deno:bin /deno /usr/local/bin/deno

WORKDIR /app

# Install Python requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source code
COPY studio studio
COPY web web

# Pre-download the speech recognition model (~480 MB) into the image
# This ensures zero-delay startup and prevents cloud healthcheck timeouts
ENV PEAKCUT_MODELS=/app/models
RUN python -m studio.fetch_model

# Environment settings
ENV PEAKCUT_DATA=/data \
    PEAKCUT_MODELS=/app/models \
    PEAKCUT_HOST=0.0.0.0 \
    PEAKCUT_PORT=8765 \
    PEAKCUT_TRUST_PROXY=1 \
    PYTHONUNBUFFERED=1

# Volume for user data, SQLite db, uploaded videos, and rendered clips
VOLUME /data

# Expose standard port (can be overridden by $PORT at runtime)
EXPOSE 8765

# Dynamic health check testing /healthz on whichever port the app is bound to ($PORT or $PEAKCUT_PORT)
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s CMD python -c "import urllib.request, os; p=os.environ.get('PORT', os.environ.get('PEAKCUT_PORT', '8765')); urllib.request.urlopen(f'http://127.0.0.1:{p}/healthz', timeout=4)"

# Start server using the standard entrypoint
CMD ["python", "-m", "studio.server"]
