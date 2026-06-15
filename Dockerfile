FROM docker.io/library/alpine:3.22 AS ngrok

ARG TARGETARCH=amd64
ARG NGROK_VERSION=3.39.7

RUN apk add --no-cache unzip wget \
  && case "${TARGETARCH}" in \
    amd64) ngrok_url="https://bin.ngrok.com/a/i8c4qzU8u7K/ngrok-v3-${NGROK_VERSION}-linux-amd64.zip"; ngrok_sha="9f6b24678a110994b5a74f801b843c9ab39fddec2ee11e2d083fe0d1d9cb5cd0" ;; \
    arm64) ngrok_url="https://bin.ngrok.com/a/epCTX21j1tZ/ngrok-v3-${NGROK_VERSION}-linux-arm64.zip"; ngrok_sha="78f960fe37da93e30779c8f860a25adcbb3a2bf337a83b5e6fc30f30becad548" ;; \
    arm) ngrok_url="https://bin.ngrok.com/a/aVZvmhSk8iv/ngrok-v3-${NGROK_VERSION}-linux-arm.zip"; ngrok_sha="cea946dc5cc1a9de5fe4085fbe28ec5e7c3de933603d52f3f45d6aaa0745bca8" ;; \
    386) ngrok_url="https://bin.ngrok.com/a/WJk31CVZWD/ngrok-v3-${NGROK_VERSION}-linux-386.zip"; ngrok_sha="3691a8a44f1facfecb8e244a269a60aed45ea9627dfaafc7014626614005834f" ;; \
    *) echo "unsupported TARGETARCH=${TARGETARCH}" >&2; exit 1 ;; \
  esac \
  && wget -q -O /tmp/ngrok.zip "${ngrok_url}" \
  && echo "${ngrok_sha}  /tmp/ngrok.zip" | sha256sum -c - \
  && unzip -q /tmp/ngrok.zip -d /usr/local/bin \
  && chmod +x /usr/local/bin/ngrok

FROM docker.io/library/nginx:alpine

RUN apk add --no-cache ca-certificates

COPY --from=ngrok /usr/local/bin/ngrok /usr/local/bin/ngrok
COPY docker-entrypoint.sh /usr/local/bin/dollhouse-entrypoint

EXPOSE 80 4040

ENTRYPOINT ["/usr/local/bin/dollhouse-entrypoint"]
CMD ["http", "http://127.0.0.1:80"]
