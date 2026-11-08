# Official MinIO source for RELEASE.2025-10-15T17-29-55Z, pinned to its commit.
FROM golang:1.26-alpine AS build
RUN apk add --no-cache git ca-certificates
WORKDIR /src
RUN git init && git remote add origin https://github.com/minio/minio.git \
    && git fetch --depth=1 origin 9e49d5e7a648f00e26f2246f4dc28e6b07f8c84a \
    && git checkout --detach FETCH_HEAD
RUN CGO_ENABLED=0 go build -trimpath -o /out/minio .

FROM alpine:3.23
RUN apk add --no-cache ca-certificates && addgroup -S -g 10001 storage \
    && adduser -S -u 10001 -G storage storage && mkdir /data && chown storage:storage /data
COPY --from=build /out/minio /usr/local/bin/minio
COPY --from=build /src/LICENSE /licenses/minio-AGPL-3.0
USER storage
EXPOSE 9000 9001
ENTRYPOINT ["minio"]
CMD ["server", "/data", "--console-address", ":9001"]
