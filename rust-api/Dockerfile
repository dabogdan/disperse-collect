# Stage 1: Build the application
FROM rust:1.69 as builder
WORKDIR /usr/src/app
COPY . .
# Build the release binary
RUN cargo build --release

# Stage 2: Create a lightweight final image
FROM debian:buster-slim
WORKDIR /app
COPY --from=builder /usr/src/app/target/release/rust-api /usr/local/bin/rust-api

# Expose the port that the app will run on
EXPOSE 8000

# Run the application
CMD ["rust-api"]