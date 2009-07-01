#! /bin/zsh

# NVIDIA settings. {{{

if which nvidia-settings && lspci -q 'VGA compatible controller: nVidia'
then
  nvidia-settings -a InitialPixmapPlacement=2 -a GlyphCache=1
fi

# }}}

# SSH agent. {{{

if { [ -z "$SSH_AUTH_SOCK" ] || [ -z "$SSH_AGENT_PID" ]; } && [ ! -f "$HOME/.ssh/noagent" ]
then
  eval "`command ssh-agent -s`" &&
fi

# }}}

# DBUS. {{{

if test -z "$DBUS_SESSION_BUS_ADDRESS"
then
  eval `dbus-launch --sh-syntax --exit-with-session`
  echo "D-BUS per-session daemon address is: $DBUS_SESSION_BUS_ADDRESS"
fi

# }}}

# X11. {{{

X11DIR="$HOME/.x11"

xhost +local:

xset b off
xset r on
xset r rate 300 50
setxkbmap -option compose:rwin
xrdb -merge -I"$X11DIR/Xresources.d" "$X11DIR/Xresources"

# }}}

# Synergy {{{

# server
cfg="$HOME/.synergys.conf"
if [[ -r "$cfg" ]]
then
  synergys --config "$cfg" --daemon
fi

# client
cfg="$HOME/.synergyc.conf"
if [[ -r "$cfg" ]]
then
  synergyc `cat "$cfg"`
fi

# }}}

# Fetchmail. {{{

if which fetchmail && [[ -r "$HOME/.fetchmailrc" ]]
then
  fetchmail
fi

# }}}

# Pulseaudio. {{{

if which pulseaudio
then
  pulseaudio --daemonize --high-priority=1 --realtime=1
fi

# }}}

# MPD/sonata startup. {{{

if which mpd sonata
then
  (mpd && sonata) &
fi

# }}}

export XSESSION_PID=$$

ion3 &

WM_PID=$!

kill -STOP $XSESSION_PID

wait $WM_PID

# MPD/sonata cleanup. {{{

eval "$HAS_MPD_SONATA" && { pkill -u $UID -f sonata; mpd --kill; }

# }}}

# vim: ft=sh sw=2 foldmethod=marker
