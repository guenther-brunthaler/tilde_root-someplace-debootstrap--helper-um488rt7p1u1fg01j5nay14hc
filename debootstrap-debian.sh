#! /bin/sh
set -e
trap 'test $? = 0 || echo "\"$0\" failed!" >& 2' 0

exit_help() {
	cat << '.'
Supported phases, execute then in this order:

help: Display this help
download: Download template for offline installation
create: Create base system offline using downloaded template
setup: Mount proc, sys etc. as required by root jail
enter: Enter root jail
teardown: Unmount whatever "setup" has mounted
purge: Delete base system since "download" phase

"help" works always.

Except for "download" and "help", all phases need the path of the
download directory as their first argument.

This name is the same as that of the template directory created
by "download", but with the ".tpl"-suffix removed.

If a PGP key is missing, do this:

$ gpg --receive-key $HEX_KEY_ID
$ gpg --export $HEX_KEY_ID | apt-key add -

Version 2022.282
Copyright (c) 2019-2022 Guenther Brunthaler. All rights reserved.

This script is free software.
Distribution is permitted under the terms of the GPLv3.
.
}

arch=
while getopts a: opt
do
	case $opt in
		a) arch=$OPTARG;;
		*) false || exit
	esac
done
shift `expr $OPTIND - 1 || :`

test "$arch"

case $1 in
download)

distro=debian
suite=bullseye
url='http://debian.inode.at/debian/'
pkgs=
{
	while read pkg
	do
		pkgs=$pkgs${pkgs:+,}$pkg
	done
	# Following this loop comes a "here-doc" list of packages not required
	# by debootstrap which shall still be included in the created
	# filesystem contents. May be an empty list.
} <<- '----'
	debian-archive-keyring
	sysvinit-core
----
# Currently disabled former entries from above HERE-DOC, kept here so the may
# be re-enabled later by moving them back.
true << '----'
----
out=$distro-$arch-`date +%Y%m%d`.tpl
test ! -e "$out" || exit
# $ git clone --depth=1 https://salsa.debian.org/installer-team/debootstrap.git
dbs=debootstrap/debootstrap
test -f "$dbs"
test -x "$dbs" || dbs="sh '$dbs'"
#	--include="$pkgs" --foreign "$suite" "$out" "$url"
DEBOOTSTRAP_DIR=$PWD/debootstrap $dbs \
	--arch="$arch" --variant=minbase --foreign "$suite" "$out" "$url"
echo "*** CREATED $out"
exit
;;

help)
exit_help

esac

if test "$2" != create
then
	test -d "$1"
fi

case $2 in
create)
test -d "$1".tpl
test ! -e "$1"
cp -r -- "$1".tpl "$1"
DEBOOTSTRAP_DIR=$1/debootstrap "$1"/debootstrap/debootstrap \
	--arch="$arch" \
	--second-stage --second-stage-target "`readlink -f -- "$1"`"
;;

setup)

cd -- "$1"
mount --rbind /sys sys
mount --rbind /proc proc
mount --rbind /dev dev
mount -t tmpfs -o mode=1777,rw,nosuid,nodev,relatime,size=2g jail_tmp tmp
mount -t tmpfs -o rw,nosuid,nodev,noexec,relatime,size=100m,mode=755 jail_run run
for m in run/lock run/shm
do
	mkdir -m 0 $m
	chown nobody:nogroup $m
done
mount -t tmpfs -o rw,nosuid,nodev,noexec,relatime,size=5m jail_lock run/lock
mount -t tmpfs -o rw,nosuid,nodev,noexec,relatime,size=400m jail_shm run/shm
;;

enter)
cd -- "$1"
unshare -u chroot . usr/bin/env -i TERM=$TERM HOME=/root bin/bash -l
;;

teardown)
cd -- "$1"
umount tmp/
umount run/lock/
umount run/shm/
umount run
umount dev/pts
umount dev
umount sys/fs/pstore/
umount sys
umount proc
;;

purge)
rm --one-file-system -rf -- "$1"
;;

help)
exit_help

esac
