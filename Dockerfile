# Build stage: compile the Dart Frog server to a standalone executable.
FROM dart:stable AS build

RUN dart pub global activate dart_frog_cli

WORKDIR /app

COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart_frog build
RUN dart compile exe build/bin/server.dart -o build/bin/server

# Runtime stage: minimal image with just the compiled executable.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/build/bin/server /app/bin/server

# Render sets $PORT; the server must bind to it (see routes/index.dart / main
# entrypoint config — Dart Frog reads PORT automatically).
EXPOSE 8080
CMD ["/app/bin/server"]
