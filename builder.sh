#!/usr/bin/env bash
set -e
set -o pipefail

main() {
	mkdir --parents /out/cache/custom/{src,pkg} /out/cache/pkg /home/custompkgs
		mv /out/cache/pkg/* /var/cache/pacman/pkg/. || true 
	
	pacman-key --init
	pacman --sync --refresh --noconfirm archlinux-keyring
	pacman --sync --refresh --sysupgrade --noconfirm --needed git pacman-contrib
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

	if test -d /home/sources; then
				ls -al /home/sources
		fi

	useradd --create-home archie
	chown --recursive archie /out /home/custompkgs /packages
	echo "archie ALL=(ALL) NOPASSWD: /usr/bin/pacman" > "/etc/sudoers.d/allow_archie_to_pacman"
	echo "root ALL=(ALL) CWD=* ALL" > /etc/sudoers.d/permissive_root_Chdir_Spec

	rm -rf /home/custompkgs/*
	runuser -u archie -- repo-add /home/custompkgs/custom.db.tar.gz
	find /out/cache/custom/pkg -type f -name '*.pkg.tar.zst' -exec runuser -u archie -- repo-add /home/custompkgs/custom.db.tar.gz {} \;

	if ! grep 'custom.conf' /etc/pacman.conf; then
		echo "Include = /etc/pacman.d/custom.conf" >> /etc/pacman.conf
	fi
	cat <<-'EOF' > "/etc/pacman.d/custom.conf"
		[custom]
		SigLevel = Optional TrustAll
		Server = file:///home/custompkgs
	EOF
	echo 'PKGDEST=/out/cache/custom/pkg' > /etc/makepkg.conf.d/pkgdest.conf
	echo 'SRCPKGDEST=/out' > /etc/makepkg.conf.d/srcpkgdest.conf
	echo 'SRCDEST=/out/cache/custom/src' > /etc/makepkg.conf.d/srcdest.conf
	echo 'OPTIONS=(!debug)' > /etc/makepkg.conf.d/nodebug.conf

	pacman --sync --refresh --sysupgrade --noconfirm

	echo "ls cache A"
	#ls -al /home/custompkgs
	#ls -al /home/sources
	zcat /home/custompkgs/custom.db.tar.gz | tar -tv

	runuser -u archie -- makepkg-url "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=paru" --syncdeps --install --clean --noconfirm --rmdeps

	runuser -u archie -- makepkg-url "https://aur.archlinux.org/cgit/aur.git/plain/{PKGBUILD,aurutils.changelog,aurutils.install}?h=aurutils" --syncdeps --install --clean --noconfirm --rmdeps

	echo "ls cache B"
	ls -al /out
	#ls -al /home/custompkgs
	#ls -al /home/sources
	zcat /home/custompkgs/custom.db.tar.gz | tar -tv

	tehbuild() {
		cd "${1}"
		if test -f PKGBUILD; then
			if ! grep '^# do not build' PKGBUILD; then
				echo "Building $(basename "$(pwd)")"
				runuser -u archie -- makepkg --printsrcinfo > .SRCINFO
				runuser -u archie -- makepkg --allsource  # --sign
				rm .SRCINFO
				runuser -u archie -- paru --upgrade --noconfirm
				for f in $(runuser -u archie -- makepkg --packagelist); do
					echo "it is ${f}"
					ln -s ./cache/custom/pkg/$(basename "${f}") /out/.
				done
				#mv *.pkg.tar.zst.sig /out/.
			else
				echo "Skipping $(pwd) because # do not build in PKGBUILD"
			fi
		else
			echo "Skipping $(pwd) because no PKGBUILD"
		fi
	}
	
	export -f tehbuild
	find /packages/ -maxdepth 1 -type d -exec bash -c 'tehbuild "${0}"' "{}" \;
	git clean -ffxd || true
	paccache -rk1
	paccache -m /out/cache/pkg -k0
	pacman -Scc
	runuser -u archie -- paru -Sccd
	clean_orphans
	rm -rf /home/archie/.cargo

	echo "ls cache C"
	#ls -al /home/custompkgs
	#ls -al /home/srcpackages
	#ls -al /home/sources
	ls -al /out
	ls -al /out/cache/pkg
	ls -al /out/cache/custom/src
	ls -al /out/cache/custom/pkg
	zcat /home/custompkgs/custom.db.tar.gz | tar -tv
}

clean_orphans() {
	ORPHANS="$(pacman --query --unrequired --deps --quiet || true)"
	if test ! -z "${ORPHANS}"; then
		sudo pacman --remove --nosave --recursive --noconfirm ${ORPHANS}
	fi
}

main
