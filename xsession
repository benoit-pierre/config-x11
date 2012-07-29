#! /bin/zsh -l

# Output logging. {{{

redirect-output()
{
  exec 1>>"$HOME/.xsession-errors" 2>&1
}

log()
{
  echo "`date --rfc-3339=seconds` -- $@"
}

redirect-output

# }}}

log 'starting'

X11DIR="$HOME/.x11"

# Logrotate ~/.xsession-errors. {{{

if which logrotate
then
  ( cd "$HOME" && logrotate -s "$X11DIR"/logrotate.{status,conf} )
  redirect-output
fi

# }}}

# NVIDIA settings. {{{

if which nvidia-settings && lspci | grep -q 'VGA compatible controller: nVidia'
then
  nvidia-settings -a InitialPixmapPlacement=2 -a GlyphCache=1
fi

# }}}

# SSH/GPG agents. {{{

ssh-gpg-agents

# }}}

# DBUS. {{{

if [[ -z "$DBUS_SESSION_BUS_ADDRESS" ]]
then
  eval `dbus-launch --sh-syntax --exit-with-session`
  echo "D-BUS per-session daemon address is: $DBUS_SESSION_BUS_ADDRESS"
fi

# }}}

# X11. {{{

# Allow local connections.
xhost +local:

# No bell.
xset b off

# Keyboard configuration.
setxkbd

# Resources.
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

if which mpd mpdscribble sonata
then
  (mpd && mpdscribble && sonata) &
fi

# }}}

# Reboot/Shutdown support using shutdown helper. {{{

final_action=''

trap 'final_action=reboot' USR1
trap 'final_action=halt' USR2

# }}}

export XSESSION_PID=$$

awesome &

WM_PID=$!

kill -STOP $XSESSION_PID

wait $WM_PID

# MPD/sonata cleanup. {{{

eval "$HAS_MPD_SONATA" && { pkill -u $UID -f sonata; mpd --kill; }

# }}}

case "$final_action" in
  reboot) shutdown -r ;;
  halt) shutdown -h ;;
  *) log 'terminating' ;;
esac

# vim: ft=sh sw=2 foldmethod=marker
