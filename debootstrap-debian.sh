#! /bin/sh
set -e
trap 'test $? = 0 || echo "\"$0\" failed!" >& 2' 0

exit_help() {
	cat << '.'
Supported phases, in order:

help: Display this help
download: Download template for offline installation
create: Create base system offline using downloaded template
setup: Mount proc, sys etc. as required by root jail
enter: Enter root jail
teardown: Unmount whatever "setup" has mounted
purge: Delete base system since "download" phase

"help" works always.

Except for "download" and "help", all phases need the path of the download
directory as their first argument.

Version 2019.319
.
}

case $1 in
download)

distro=debian
suite=buster
url='http://debian.inode.at/debian/'
keyring=~/.gnupg/pubring.gpg
pkgs=
while read pkg
do
	pkgs=$pkgs${pkgs:+,}$pkg
done <<- '----'
----
# Disabled:
true << '----'
	devuan-keyring
	sysvinit-core
----
test -f "$keyring"
out=$distro-`date +%Y%m%d`.tpl
test ! -e "$out" || exit
dbs=`command -v debootstrap 2> /dev/null || ./debootstrap`
test -f "$dbs"
test -x "$dbs" || dbs="sh '$dbs'"
#	--include="$pkgs" --foreign "$suite" "$out" "$url"
$dbs --keyring="$keyring" --variant=minbase \
	--foreign "$suite" "$out" "$url"
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
