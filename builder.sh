#!/usr/bin/env bash
set -e
set -o pipefail

main() {
	pacman-key --init
	pacman --sync --refresh --noconfirm archlinux-keyring
	pacman --sync --refresh --sysupgrade --noconfirm git
	git config --global --add safe.directory /packages

	echo "ls cache 0"
	ls -al /home
	if test -d /home/custompkgs; then
		ls -al /home/custompkgs
		if test -f /home/custompkgs/custom.db.tar.gz; then
			zcat /home/custompkgs/custom.db.tar.gz | tar -tv
		fi
	fi
	if test -d /home/srcpackages; then
		ls -al /home/srcpackages
	fi

	useradd --create-home archie
	echo "archie ALL=(ALL) NOPASSWD: /usr/bin/pacman" > "/etc/sudoers.d/allow_archie_to_pacman"
	echo "root ALL=(ALL) CWD=* ALL" > /etc/sudoers.d/permissive_root_Chdir_Spec

	mkdir --parents /out /home/srcpackages
	chown --recursive archie /packages /out /home/custompkgs /home/srcpackages

	rm -rf /home/custompkgs/custom.db.tar.gz
	rm -rf /home/custompkgs/custom.db
	rm -rf /home/custompkgs/custom.files.tar.gz
	rm -rf /home/custompkgs/custom.files
	run0 -u archie -- repo-add /home/custompkgs/custom.db.tar.gz
	find /home/custompkgs -type f -name '*.pkg.tar.zst' -exec run0 -u archie -- repo-add /home/custompkgs/custom.db.tar.gz {} \;

	if ! grep 'custom.conf' /etc/pacman.conf; then
			echo "Include = /etc/pacman.d/custom.conf" >> /etc/pacman.conf
		fi
	cat <<-'EOF' > "/etc/pacman.d/custom.conf"
		[custom]
		SigLevel = Optional TrustAll
		Server = file:///home/custompkgs
	EOF
	echo 'PKGDEST=/home/custompkgs' > /etc/makepkg.conf.d/pkgdest.conf
	echo 'SRCPKGDEST=/home/srcpackages' > /etc/makepkg.conf.d/srcpkgdest.conf
	echo 'OPTIONS=(!debug)' > /etc/makepkg.conf.d/nodebug.conf

	pacman --sync --refresh --sysupgrade --noconfirm

	echo "ls cache A"
	ls -al /home/custompkgs
	ls -al /home/srcpackages
	zcat /home/custompkgs/custom.db.tar.gz | tar -tv

	run0 -u archie -- makepkg-url "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=paru" --syncdeps --install --clean --noconfirm --rmdeps
	clean_orphans

	run0 -u archie -- makepkg-url "https://aur.archlinux.org/cgit/aur.git/plain/{PKGBUILD,aurutils.changelog,aurutils.install}?h=aurutils" --syncdeps --install --clean --noconfirm --rmdeps
	clean_orphans

	echo "ls cache B"
	ls -al /home/custompkgs
	ls -al /home/srcpackages
	zcat /home/custompkgs/custom.db.tar.gz | tar -tv

	cd /packages
	find -name PKGBUILD -execdir sh -c 'run0 -u archie -- makepkg --printsrcinfo > .SRCINFO' \;
	for d in */ ; do
		pushd "${d}"
		if test ! -f DONTBUILD -a -f PKGBUILD; then
			echo "building $(pwd) version $(getver)"

			TMPDIR=$(run0 -u archie -- mktemp -p /var/tmp --directory)
			SRCPKGDEST="${TMPDIR}" run0 --setenv=SRCPKGDEST -u archie -- makepkg --allsource  # --sign
			cp ${TMPDIR}/*.src.tar.gz /home/srcpackages/.
			mv ${TMPDIR}/*.src.tar.gz /out/.
			TMPDIR=$(run0 -u archie -- mktemp -p /var/tmp --directory)
			PKGDEST="${TMPDIR}" run0 --setenv=PKGDEST -u archie -- paru --upgrade --noconfirm
			clean_orphans
			cp ${TMPDIR}/*.pkg.tar.zst /home/custompkgs/.
			mv ${TMPDIR}/*.pkg.tar.zst /out/.
			#mv *.pkg.tar.zst.sig /out/.
			sudo --user=archie --chdir=~ bash -c "rm --recursive --force ~/.cargo"
		else
			echo "Skipping ${d}"
		fi
		popd
	done
	git clean -ffxd || true

	echo "ls cache C"
	ls -al /home/custompkgs
	ls -al /home/srcpackages
	zcat /home/custompkgs/custom.db.tar.gz | tar -tv
}

getver() {
		SRCINFO="$(run0 -u archie -- makepkg --printsrcinfo)"
		pkgver=$(awk '$1 == "pkgver" { print $3}' <<< "${SRCINFO}")
		pkgrel=$(awk '$1 == "pkgrel" { print $3}' <<< "${SRCINFO}")
		epoch=$(awk '$1 == "epoch" { print $3}' <<< "${SRCINFO}")
		if test -z "${epoch}"; then
				printf ${pkgver}-${pkgrel}
		else
				printf ${epoch}:${pkgver}-${pkgrel}
		fi
}

clean_orphans() {
	ORPHANS="$(pacman --query --unrequired --deps --quiet || true)"
	if test ! -z "${ORPHANS}"; then
		sudo pacman --remove --nosave --recursive --noconfirm ${ORPHANS}
	fi
}

main
