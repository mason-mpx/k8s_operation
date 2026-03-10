# ---------- builder ----------
ARG GO_VERSION=1.24
FROM swr.cn-east-3.myhuaweicloud.com/kubesre/docker.io/golang:${GO_VERSION} AS builder

WORKDIR /src
ENV GOPROXY=https://goproxy.cn,https://goproxy.io,direct
ENV CGO_ENABLED=0
ENV GOOS=linux
ENV GOARCH=amd64

ARG BIN_NAME=k8s_operation

COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go mod download && go mod verify

COPY . .

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -trimpath -ldflags="-s -w" -o /out/${BIN_NAME} ./cmd/k8soperation


# ---------- runtime ----------
FROM swr.cn-east-3.myhuaweicloud.com/kubesre/docker.io/alpine:3.20

RUN apk add --no-cache ca-certificates tzdata wget && \
    addgroup -S app && adduser -S app -G app

WORKDIR /app
RUN mkdir -p /app/storage/logs /app/configs

COPY --from=builder /out/k8s_operation /app/k8s_operation

RUN chown -R app:app /app
USER app

ENV GIN_MODE=release
ENV APP_CONFIG=/app/configs/config.yaml
ENV K8S_CONFIG=/app/configs/k8s.yaml

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -qO- http://127.0.0.1:8080/healthz/live || exit 1

ENTRYPOINT ["/app/k8s_operation"]