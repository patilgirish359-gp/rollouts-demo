FROM golang:1.22-alpine AS build
WORKDIR /src
COPY . .
# Build a static binary
RUN apk add --no-cache git && \
    CGO_ENABLED=0 GOOS=linux go build -o /out/rollouts-demo

FROM gcr.io/distroless/base-debian12:nonroot
WORKDIR /app
COPY *.html ./
COPY *.png ./
COPY *.js ./
COPY *.ico ./
COPY *.css ./
COPY *.map ./
COPY --from=build /out/rollouts-demo /app/rollouts-demo

ARG COLOR
ENV COLOR=${COLOR}
ARG ERROR_RATE
ENV ERROR_RATE=${ERROR_RATE}
ARG LATENCY
ENV LATENCY=${LATENCY}

EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/app/rollouts-demo"]
