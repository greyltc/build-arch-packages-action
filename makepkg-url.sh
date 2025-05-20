#!/usr/bin/env bash
# builds an Arch package from files given in a (curl glob formatted) URL
# origionally from https://gist.github.com/greyltc/8a93d417a052e00372984ff8ec224703
# example usage; (re)build and install the aurutils package:
# bash <(curl -sL https://raw.githubusercontent.com/greyltc/build-arch-packages-action/60fefbbe9d167d0d1b747e456c3158745c66a6ac/makepkg-url.sh) "https://aur.archlinux.org/cgit/aur.git/plain/{PKGBUILD,aurutils.changelog,aurutils.install}?h=aurutils" --install --force

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
