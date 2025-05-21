# syntax = docker/dockerfile:1.15
FROM archlinux:base-devel AS build
COPY . /packages/
COPY builder.sh /root/
COPY makepkg-url.sh /usr/bin/makepkg-url
# --mount=type=cache seem to be broken in github actions (but this should work for local builds). see
# https://github.com/moby/buildkit/issues/1512
# https://github.com/moby/buildkit/issues/1512#issuecomment-1192878530
# something like https://github.com/moby/buildkit/issues/1512#issuecomment-1319736671 would probably need to be deployed in the dockerfile
RUN \
  --mount=type=cache,target=/home/custompkgs,sharing=locked \
  bash /root/builder.sh

FROM scratch AS export
COPY --from=build /out/* /
