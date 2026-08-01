#!/system/bin/sh

MODDIR=${0%/*}

if [ "$(readlink /proc/self/ns/mnt)" != "$(readlink /proc/1/ns/mnt)" ]; then
  exec nsenter -t 1 -m -- "$0" "$@"
fi

if [ -n "$1" ]; then
  "$MODDIR/unmount.sh" "$1"
  sleep 1
  "$MODDIR/mount-once.sh" "$1"
else
  "$MODDIR/unmount.sh"
  sleep 1
  "$MODDIR/mount-once.sh"
fi
