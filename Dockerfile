# syntax=docker/dockerfile:1-labs
FROM archlinux:base-devel AS build
ARG r2repo_sources=""
COPY --from=packages . /packages/
COPY --from=cache . /out/cache/
COPY builder.sh /root/
COPY makepkg-url.sh /usr/bin/makepkg-url
# --mount=type=cache seem to be broken in github actions (but this should work for local builds). see
# https://github.com/moby/buildkit/issues/1512
# https://github.com/moby/buildkit/issues/1512#issuecomment-1192878530
# something like https://github.com/moby/buildkit/issues/1512#issuecomment-1319736671 would probably need to be deployed here to make caching work
RUN --security=insecure ["/bin/bash", "-c", "/root/builder.sh", "${r2repo_sources}"]

# for podman:
#RUN bash /root/builder.sh

#--mount=type=cache,target=/out/cache,sharing=locked \

FROM scratch AS export
COPY --from=build /out /
