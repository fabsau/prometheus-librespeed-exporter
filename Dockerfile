# Use an argument for the target architecture
ARG TARGET_ARCH=

# Start from the latest alpine image with the target architecture
FROM ${TARGET_ARCH}alpine:latest as base

# Install necessary packages
RUN apk add --no-cache jq tar curl ca-certificates bash

# Create a shared function for detecting architecture, usable in later stages
RUN echo $'#!/bin/sh\n\
ARCH=$(apk info --print-arch)\n\
echo "ARCH=${ARCH}"\n\
case "$ARCH" in\n\
    x86_64) _arch=amd64 ;;\n\
    armhf) _arch=armv7 ;;\n\
    armv7) _arch=armv7 ;;\n\
    aarch64) _arch=arm64 ;;\n\
    *) echo >&2 "unsupported architecture"; exit 1 ;;\n\
esac\n\
echo "_arch=${_arch}"' > /tmp/arch-detection.sh && chmod +x /tmp/arch-detection.sh

# Stage 1: Download and install the librespeed-cli command-line tool
FROM base as librespeed-builder
ENV CLI_VERSION=1.0.10
RUN source /tmp/arch-detection.sh && \
    URL="https://github.com/librespeed/speedtest-cli/releases/download/v${CLI_VERSION}/librespeed-cli_${CLI_VERSION}_linux_${_arch}.tar.gz" && \
    echo "Pulling CLI from ${URL}" && \
    curl -fsSL -o /tmp/cli.tgz "${URL}" && \
    tar xvzf /tmp/cli.tgz -C /usr/local/bin librespeed-cli && \
    rm /tmp/cli.tgz

# Stage 2: Download and install the script_exporter binary
FROM base as script-exporter-builder
ENV SCRIPT_EXPORTER_VERSION=2.16.0
RUN source /tmp/arch-detection.sh && \
    URL="https://github.com/ricoberger/script_exporter/releases/download/v${SCRIPT_EXPORTER_VERSION}/script_exporter-linux-${_arch}" && \
    echo "Pulling script_exporter from ${URL}" && \
    curl -kfsSL -o /usr/local/bin/script_exporter "${URL}" && \
    chmod 700 /usr/local/bin/script_exporter

# Final stage: Combine everything into the final Docker image.
FROM base

#Creating non-root user
RUN adduser -S appuser -u 1001
USER 1001

# Specify a working directory
WORKDIR /home/appuser

# Copy files from builder stages and setup final Docker image
COPY --from=librespeed-builder /usr/local/bin/librespeed-cli /usr/local/bin/
COPY --from=script-exporter-builder /usr/local/bin/script_exporter /usr/local/bin/
COPY config.yaml ./config.yaml
COPY librespeed-exporter.sh /usr/local/bin/librespeed-exporter.sh

# Expose port
EXPOSE 9469

# Application Entrypoint
ENTRYPOINT [ "/usr/local/bin/script_exporter" ]