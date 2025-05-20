# syntax = docker/dockerfile:1.15
FROM archlinux:base-devel AS build
COPY . /packages/
COPY builder.sh /root/
COPY makepkg-url.sh /usr/bin/makepkg-url
RUN --mount=type=cache,target=/home/custompkgs,sharing=locked bash /root/builder.sh

FROM scratch AS export
COPY --from=build /out/* /
