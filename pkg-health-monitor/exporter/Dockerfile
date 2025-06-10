# exporter/Dockerfile — container image for Prometheus exporter
FROM alpine:3.18

RUN apk add --no-cache bash coreutils ncurses-openbsd

# Create non-root user
RUN addgroup -S exporter && adduser -S -G exporter exporter

USER exporter
WORKDIR /home/exporter

COPY --chown=exporter:exporter exporter.sh .

EXPOSE 9100

ENTRYPOINT ["./exporter.sh"]
