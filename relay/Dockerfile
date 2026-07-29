# Build a self-contained native binary, then ship it on a bare image so the
# running container is a few megabytes with no Dart SDK inside.
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline
RUN dart compile exe bin/server.dart -o bin/relay

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/relay /app/bin/relay

ENV PORT=8080
EXPOSE 8080
CMD ["/app/bin/relay"]
