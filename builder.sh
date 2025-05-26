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
	cat <<- 'EOF' > /etc/pacman.d/custom.conf
		[custom]
		SigLevel = Optional TrustAll
		Server = file:///home/custompkgs
	EOF
	echo 'PKGDEST=/out/cache/custom/pkg' > /etc/makepkg.conf.d/pkgdest.conf
	echo 'SRCPKGDEST=/out' > /etc/makepkg.conf.d/srcpkgdest.conf
	echo 'SRCDEST=/out/cache/custom/src' > /etc/makepkg.conf.d/srcdest.conf
	echo 'OPTIONS=(!debug)' > /etc/makepkg.conf.d/nodebug.conf

	pacman --sync --refresh --sysupgrade --noconfirm

	# bootstrap
 	echo "Bootstrapping paru"
	runuser -u archie -- makepkg-url "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=paru" --syncdeps --install --clean --noconfirm --rmdeps
	echo "Bootstrapping aurutils"
 	runuser -u archie -- makepkg-url "https://aur.archlinux.org/cgit/aur.git/plain/{PKGBUILD,aurutils.changelog,aurutils.install}?h=aurutils" --syncdeps --install --clean --noconfirm --rmdeps

 	echo "Cache is $(ls /out/cache/custom/pkg)"
  	#echo 1 > /proc/sys/kernel/unprivileged_userns_clone

	tehbuildloop() {
		cd "${1}"
		if test -f PKGBUILD; then
			if ! grep '^# do not build' PKGBUILD; then
   				if test ! -f /tmp/fail; then
				echo "Considering $(basename "$(pwd)")"
					for f in $(runuser -u archie -- makepkg --packagelist); do
	    					echo "Looking for ${f}"
	    					if test -f "${f}"; then
		 					echo "We already had ${f}"
	       						ls -al /out/cache/custom/pkg
	       					else
							echo "Building $(basename "$(pwd)")"
							runuser -u archie -- paru --upgrade --noconfirm
		    					if test -f "${f}"; then
								echo "Done building $(basename "$(pwd)")"
		       						ln -s ./cache/custom/pkg/$(basename "${f}") /out/.
								runuser -u archie -- makepkg --allsource  # --sign
		      						#mv *.pkg.tar.zst.sig /out/.
	       						else
		     						touch /tmp/fail
		    					fi
	      						break
		 				fi
					done
     				else
					echo "Skipping $(pwd) because of precious failure"
  				fi
			else
				echo "Skipping $(pwd) because # do not build in PKGBUILD"
			fi
		else
			echo "Skipping $(pwd) because no PKGBUILD"
		fi
	}
	export -f tehbuildloop
 
	find /packages/ -maxdepth 1 -type d -exec bash -c 'tehbuildloop "${0}"' "{}" \;
 	if test -f /tmp/fail; then
  		echo "ERROR: Couldn't find ${f} after building it."
    		exit -44
      	fi

	git clean -ffxd || true
	paccache --remove --keep 1
 	paccache --remove --keep 1 --min-mtime "1 day ago" --cachedir /out/cache/custom/pkg
  	# /out/cache/custom/src will grow unboundedly...just clear it every now and then with this?
   	# rm -f /out/cache/custom/src/*
	paccache -m /out/cache/pkg -k0
	yes | pacman -Scc || true
	yes | runuser -u archie -- paru -Sccd || true
	clean_orphans
	rm -rf /home/archie/.cargo
}

clean_orphans() {
	ORPHANS="$(pacman --query --unrequired --deps --quiet || true)"
	if test ! -z "${ORPHANS}"; then
		sudo pacman --remove --nosave --recursive --noconfirm ${ORPHANS}
	fi
}

main
