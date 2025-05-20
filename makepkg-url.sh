#!/usr/bin/env bash
# builds an Arch package from files given in a (curl glob formatted) URL
# example usage; (re)build and install the aurutils package:
# from https://gist.github.com/greyltc/8a93d417a052e00372984ff8ec224703

set -e

TMPDIR=$(mktemp -p /var/tmp --directory)
touch "${TMPDIR}/.deleteme"

main() {
  trap clean_up EXIT

  URL="$1"; shift

  pushd "${TMPDIR}" > /dev/null

  curl --silent --remote-name "${URL}"

  makepkg --clean "$@"

  popd > /dev/null
}

clean_up () {
  CODE=$?
  # echo "Cleaning up ${TMPDIR}"
  if test -f "${TMPDIR}/.deleteme"; then
    rm --force --recursive "${TMPDIR}"
  else
    echo "Not cleaning up."
  fi
  exit ${CODE}
}

main "$@"
