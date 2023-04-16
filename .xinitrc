#!/bin/sh

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
    for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
         [ -x "$f" ] && . "$f"
          done
           unset f
fi

systemctl --user set-environment DISPLAY=:0

export $(dbus-launch)

exec i3
