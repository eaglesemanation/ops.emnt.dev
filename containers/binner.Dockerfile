FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base

WORKDIR /app
USER root
RUN apt-get update && \
    apt-get install -y --no-install-recommends wget ca-certificates && \
    rm -rf /var/lib/apt/lists/*

ARG ARCH=x64
ARG RELEASE_TAG=2.6.3
ARG ARTIFACT_NAME=Binner_linux-${ARCH}-${RELEASE_TAG}.tar.gz

RUN wget https://github.com/replaysMike/Binner/releases/download/v${RELEASE_TAG}/${ARTIFACT_NAME} -O /app/${ARTIFACT_NAME} && \
    tar -xzf /app/${ARTIFACT_NAME} -C /app && \
    rm /app/${ARTIFACT_NAME} && \
    chown -R 1000:1000 /app && \
    chmod +x /app/Binner.Web

USER app
EXPOSE 8090
ENTRYPOINT ["/app/Binner.Web"]

LABEL org.opencontainers.image.authors="Vladimir Romashchenko <eaglesemanation@gmail.com>"
LABEL org.opencontainers.image.source="https://github.com/eaglesemanation/ops.emnt.dev"
LABEL org.opencontainers.image.licenses="GPL-3.0"
