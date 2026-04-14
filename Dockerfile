# Stage 1: compile tempo.so from devlake monorepo context (skips libgit2)
# Build context must be apache-devlake/backend/
FROM --platform=linux/amd64 golang:1.20-bookworm AS builder

RUN apt-get update && apt-get install -y gcc

WORKDIR /app
COPY . .

ENV CGO_ENABLED=1
ENV GOARCH=amd64
ENV GOOS=linux

RUN --mount=type=cache,target=/root/.cache/go-build \
    go build -buildmode=plugin \
    -o /tempo.so \
    ./plugins/tempo/

# Stage 2: layer tempo.so on existing image (has PR bitbucket fix + full devlake)
FROM europe-west1-docker.pkg.dev/abs-digital-playground/apache-devlake/devlake:fix-bitbucket-microsecond-timestamp

USER root
RUN mkdir -p /app/bin/plugins/tempo
COPY --from=builder /tempo.so /app/bin/plugins/tempo/tempo.so
RUN chown -R 1010:1010 /app/bin/plugins/tempo
USER 1010
