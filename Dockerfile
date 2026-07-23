# Agent DVR 7.7.4.0
# FFmpeg is bundled inside the Agent zip as of recent 7.x - there is no
# separate ffmpeg7 tarball to download. The old blob URL now 404s.

FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=America/Los_Angeles

# Primary CDN, with the GitHub release mirror as fallback.
# To change version, update BOTH of these.
ARG FILE_LOCATION="https://files.ispyconnect.com/downloads/Agent_Linux64_7_7_4_0.zip"
ARG MIRROR_LOCATION="https://github.com/ispysoftware/agent-install-scripts/releases/download/v7.7.4.0/Agent_Linux64_7_7_4_0.zip"

# Core dependencies - mirrors the official v3 installer's apt list
RUN apt-get update \
    && apt-get install --no-install-recommends -y \
        ca-certificates \
        wget \
        curl \
        unzip \
        xz-utils \
        apt-transport-https \
        alsa-utils \
        libxext-dev \
        fontconfig \
        libva-drm2 \
        tzdata

# VAAPI GPU drivers - best effort, non-fatal.
# Only useful if you pass /dev/dri into the container at runtime.
RUN apt-get install --no-install-recommends -y mesa-va-drivers || echo "mesa-va-drivers unavailable - AMD VAAPI disabled" \
    && apt-get install --no-install-recommends -y intel-media-va-driver || echo "intel driver unavailable - QuickSync disabled"

# Download Agent DVR, falling back to the GitHub mirror if the CDN is throttled
RUN wget -c "${FILE_LOCATION}" -O agent.zip \
    || wget -c "${MIRROR_LOCATION}" -O agent.zip

RUN unzip agent.zip -d /agent \
    && rm agent.zip

# Sanity check: confirm the bundled ffmpeg actually arrived.
# Fails the build loudly rather than at runtime if the layout changes again.
RUN find /agent -iname "*ffmpeg*" -maxdepth 2 | grep -q . \
    || (echo "ERROR: no ffmpeg found in the Agent package - check the zip layout" && exit 1)

# Permissions - discover scripts rather than hardcoding names
RUN chmod +x /agent/Agent \
    && find /agent -name "*.sh" -exec chmod +x {} \; \
    && if [ -f /agent/TURN/turnserver ]; then chmod +x /agent/TURN/turnserver; fi

# Cleanup
RUN apt-get -y --purge remove wget \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# Mitigates a memory leak on encoded recording
ENV MALLOC_TRIM_THRESHOLD_=100000

# Main UI port. Override by placing a port.txt containing the port number
# in /agent/Media/XML/
EXPOSE 8090
# STUN
EXPOSE 3478/udp
# TURN relay range - must match <TurnServerMinPort>/<TurnServerMaxPort> in Config.xml
EXPOSE 50000-50100/udp

VOLUME ["/agent/Media/XML", "/agent/Media/WebServerRoot/Media", "/agent/Commands"]

CMD ["/agent/Agent"]
