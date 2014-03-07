#!/bin/zsh -l

[[ "x-t" != "x$1" ]]
opt_test=$?

# Crude hack to detect if we're being source;
# e.g. by /etc/lightdm/Xsession...
if [ "$(basename "$0")" != ".xsession" ]
then
  return
fi

# Output logging. {{{

redirect-output()
{
  if [[ 0 -ne $opt_test ]]
  then
    return
  fi
  exec 1>>"$HOME/.xsession-errors" 2>&1
}

log()
{
  echo "`date --rfc-3339=seconds` -- $@"
}

redirect-output

# }}}

log 'starting'

X11DIR="${XDG_CONFIG_HOME:-$HOME/.config}/x11"

# Logrotate ~/.xsession-errors. {{{

if which logrotate
then
  ( cd "$HOME" && logrotate -s "$X11DIR"/logrotate.{status,conf} )
  redirect-output
fi

# }}}

# NVIDIA settings. {{{

if which nvidia-settings && lspci | grep -qi 'vga compatible controller: nvidia'
then
  nvidia-settings --load-config-only
  nvidia-settings -a InitialPixmapPlacement=2 -a GlyphCache=1
fi

# }}}

# Background.

for p in hsetroot fbsetroot
do
 if which "$p"
 then
   "$p" -solid '#000000'
   break
 fi
done

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

# Pulseaudio. {{{

if which pulseaudio
then
  pulseaudio --daemonize
fi

# }}}

# MPD. {{{

if which mpd
then
  mpd
fi

# }}}

# XbindKeys. {{{

cfg="$HOME/.xbindkeysrc"
if [[ -r "$cfg" ]]
then
  xbindkeys
fi

# }}}

# Reboot/Shutdown support using shutdown helper. {{{

final_action=''

trap 'final_action=reboot' USR1
trap 'final_action=halt' USR2

if [[ 0 -ne $opt_test ]]
then
  export SHUTDOWN_DRYRUN=1
fi

# }}}

export XSESSION_PID=$$

awesome

# MPD. {{{

if which mpd
then
  mpd --kill
fi

# }}}

# Reboot/Shutdown support using shutdown helper. {{{

case "$final_action" in
  reboot) shutdown -r ;;
  halt) shutdown -h ;;
  *) log 'terminating' ;;
esac

# }}}

# vim: ft=zsh sw=2 foldmethod=marker
