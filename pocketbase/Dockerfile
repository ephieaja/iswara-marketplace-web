# Dockerfile untuk PocketBase ISWARA Marketplace
# Deploy ke Railway atau Render dengan Docker support

FROM alpine:3.18

RUN apk add --no-cache ca-certificates tzdata unzip curl

ENV TZ=Asia/Jakarta

WORKDIR /app

# Download PocketBase latest version
RUN curl -L https://github.com/pocketbase/pocketbase/releases/download/v0.22.0/pocketbase_0.22.0_linux_amd64.zip -o pb.zip && \
    unzip pb.zip && rm pb.zip

RUN addgroup -g 1000 pocketbase && \
    adduser -u 1000 -G pocketbase -s /bin/sh -D pocketbase

# Migrations dihapus - collections sudah dibuat manual di PocketBase Admin

EXPOSE 8091

# NOTE: Volume untuk pb_data nanti diset di Railway Dashboard
# Jangan pakai VOLUME di Dockerfile karena Railway tidak support

USER pocketbase

ENTRYPOINT ["./pocketbase"]
CMD ["serve", "--http=0.0.0.0:8091", "--dir=/app/pb_data"]

