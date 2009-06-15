#! /bin/zsh

nvidia-settings -a InitialPixmapPlacement=2 -a GlyphCache=1

X11DIR="$HOME/.x11"

# export GDK_USE_XFT=1

umask 077

if { [ -z "$SSH_AUTH_SOCK" ] || [ -z "$SSH_AGENT_PID" ]; } && [ ! -f "$HOME/.ssh/noagent" ]
then
  eval "`command ssh-agent -s`" &&
fi

if test -z "$DBUS_SESSION_BUS_ADDRESS"
then
  eval `dbus-launch --sh-syntax --exit-with-session`
  echo "D-BUS per-session daemon address is: $DBUS_SESSION_BUS_ADDRESS"
fi

xhost +local:

xset b off
xset r on
xset r rate 300 50
xrdb -merge -I"$X11DIR/Xresources.d" "$X11DIR/Xresources"

gnome-settings-daemon &!

which pulseaudio
HAS_PULSE="[ $? -eq 0 ]"

which mpd sonata
HAS_MPD_SONATA="[ $? -eq 0 ]"

which fetchmail && [ -r "$HOME/.fetchmailrc" ]
HAS_FETCHMAIL="[ $? -eq 0 ]"

eval "$HAS_PULSE" && pulseaudio --daemonize --high-priority=1 --realtime=1
eval "$HAS_MPD_SONATA" && (mpd && sonata) &
eval "$HAS_FETCHMAIL" && fetchmail

export XSESSION_PID=$$

ion3 &

WM_PID=$!

kill -STOP $XSESSION_PID

wait $WM_PID

eval "$HAS_MPD_SONATA" && { pkill -u $UID -f sonata; mpd --kill; }

pkill -u $UID -f gnome-settings-daemon

# vim: ft=sh sw=2
