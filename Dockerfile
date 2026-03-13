# Build stage
FROM golang:alpine AS builder

# Install git for fetching dependencies
RUN apk add --no-cache git

WORKDIR /app

# Copy go mod and sum files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN go build -o main .

# Run stage
FROM alpine:latest

WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/main .

# Copy swagger docs (needed for serving swagger.json)
COPY docs ./docs

# Copy config directory (optional, if you want defaults baked in)
# We will also mount this in docker-compose for development
COPY config ./config

# Expose port (adjust if your config uses a different port)
EXPOSE 8080

# Run the application
CMD ["./main"]
