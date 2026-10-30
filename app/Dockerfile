# Build a static binary, ship it on distroless (no shell, non-root, ~10 MB).
FROM golang:1.24-alpine AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
ARG VERSION=dev
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags "-s -w -X main.version=${VERSION}" -o /out/demo-app .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/demo-app /demo-app
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/demo-app"]
