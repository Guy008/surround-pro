FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    HOME=/root \
    OUTPUT_DIR=/output \
    AUDIO_SEPARATOR_MODEL_DIR=/models/audio-separator \
    XDG_CACHE_HOME=/models

RUN apt-get update && apt-get install -y --no-install-recommends \
        bash ca-certificates curl \
        python3-pip python3-dev \
        build-essential \
        ffmpeg \
        patchelf binutils \
        locales \
        && rm -rf /var/lib/apt/lists/*

RUN pip3 install --break-system-packages --no-cache-dir --upgrade yt-dlp

RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    mv /root/.local/bin/uv /usr/local/bin/uv

WORKDIR /app
COPY surround-pro.sh ./surround-pro.sh
COPY lib/ ./lib/

RUN mkdir -p /input /output /models/audio-separator /models/torch /models/cache && \
    chmod +x surround-pro.sh lib/*.sh

VOLUME ["/input", "/output", "/models"]

ENTRYPOINT ["/app/surround-pro.sh"]
