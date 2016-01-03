#!/bin/sh

# X11 input configuration.

opt_debug=0
opt_verbose=0
opt_test=0
lang='colemak'
opt_keyboard=1
opt_mouse=1

while [ 0 -ne $# ]
do
  case "$1" in
    -d)
      opt_debug=1
      set -x
      ;;
    -k)
      opt_mouse=0
      ;;
    -m)
      opt_keyboard=0
      ;;
    -v)
      opt_verbose=1
      ;;
    -t)
      opt_test=1
      ;;
    -*)
      echo 2>&1 "setxinput: unsupported option: $1"
      exit 1
      ;;
    *)
      lang="$1"
      ;;
  esac
  shift
done

setbuttons()
{
  name="$1"
  id="$2"
  shift 2

  [ 0 -ne $opt_verbose ] && printf 'setbuttons: %2u [%-40s]: %s\n' "$id" "$name" "$*"

  xinput set-button-map "$id" "$@"
}

setkbd()
{
  name="$1"
  id="$2"
  layout="$3"
  variant="$4"
  options="$5"
  xkbdir="${XDG_CONFIG_HOME:-$HOME/.config}/x11/xkb"

  [ 0 -ne $opt_verbose ] && printf 'setkbd: %2u [%-40s]: %s|%s|%s\n' "$id" "$name" "$layout" "$variant" "$options"

  setxkbmap -layout "$layout" -variant "$variant" -option -option "$options" -print |
  sed 's/"pc+\(.*\)+inet(evdev)\([^"]*\)"\s*};$/"pc+inet(evdev)+\1\2" };/' |
  xkbcomp -w0 -I"$xkbdir" ${id:+-i "$id"} - "$DISPLAY"
}

setrazer()
{
  model="$1"
  dev="$2"
  cmd="razercfg -B -d 'Mouse:$model:$dev' -p1"

  # - shut-off mouse leds
  # - set scan frenquency to max Hz
  # - set scan resolution to max DPI

  case "$model" in
    'DeathAdder 3500DPI')
      options='-l all:off -f 0:1000 -r 0:3500'
      ;;
    'Naga 2014')
      options='-l all:off -f 0:1000 -r 0:5600'
      ;;
  esac

  [ 0 -ne $opt_verbose ] && printf 'setrazer: %-30s [%-20s]: %s\n' "$dev" "$model" "$options"

  eval "$cmd $options"
}

if [ 0 -ne $opt_keyboard ]
then
  setkbd general '' bpierre "$lang" compose:rwin
fi

xinput list |
# ⎡ Virtual core pointer                          id=2    [master pointer  (3)]
# ⎜   ↳ Virtual core XTEST pointer                id=4    [slave  pointer  (2)]
# ⎜   ↳ Xephyr virtual mouse                      id=7    [slave  pointer  (2)]
# ⎜   ↳ TypeMatrix.com USB Keyboard               id=9    [slave  pointer  (2)]
# ⎜   ↳ Logitech USB Optical Mouse                id=12   [slave  pointer  (2)]
# ⎣ Virtual core keyboard                         id=3    [master keyboard (2)]
#     ↳ Virtual core XTEST keyboard               id=5    [slave  keyboard (3)]
#     ↳ Xephyr virtual keyboard                   id=6    [slave  keyboard (3)]
#     ↳ Power Button                              id=6    [slave  keyboard (3)]
#     ↳ Power Button                              id=7    [slave  keyboard (3)]
#     ↳ TypeMatrix.com USB Keyboard               id=8    [slave  keyboard (3)]
#     ↳ Logitech USB Keyboard                     id=10   [slave  keyboard (3)]
#     ↳ Logitech USB Keyboard                     id=11   [slave  keyboard (3)]
#    ↳ TypeMatrix.com USB Keyboard               id=8    [slave  keyboard (3)]
sed -n '/^⎜\?\s\+↳\s\+\(\<.\+\>\)\s\+.*id=\([0-9]\+\)\s\+\[slave \+\(keyboard\|pointer\)\s\+([0-9]\+)\]$/{s//\2 \3 \1/;s/ \(USB \)\?\([Pp]ointer\|[Kk]eyboard\)$//;p}' |
while read id type name
do
  case "$type" in
    keyboard)
      case "$name" in
        'Power Button')
          ;;
        'Virtual core XTEST')
          ;;
        'TypeMatrix.com')
          if [ 0 -ne $opt_keyboard ]
          then
            setkbd "$name" "$id" bpierre "$lang"_typematrix
          fi
          ;;
        'Xephyr virtual')
          if [ 0 -ne $opt_keyboard ]
          then
            setkbd "$name" "$id" bpierre "$lang" compose:rwin
          fi
          ;;
        'Razer Razer Naga 2014')
          if [ 0 -ne $opt_mouse ]
          then
            setkbd "$name" "$id" razer naga_thumbgrid
          fi
          ;;
        *)
          [ 0 -ne $opt_verbose ] && echo "ignoring keyboard device: $name"
          ;;
      esac
      ;;
    pointer)
      case "$name" in
        'Virtual core XTEST')
          ;;
        'TypeMatrix.com')
          ;;
        *' CST Laser Trackball')
          if [ 0 -ne $opt_mouse ]
          then
            # Swap left/right buttons.
            setbuttons "$name" "$id" 3 2 1
          fi
          ;;
        'Razer Razer Naga 2014')
          ;;
        *)
          [ 0 -ne $opt_verbose ] && echo "ignoring pointer device: $name"
          ;;
      esac
      ;;
  esac
done

if [ 0 -ne $opt_keyboard ]
then
  # Ugly hack... otherwise keymaps are not always taken into account...
  xdotool keyup space

  # Keyboard auto-repeat:
  # - on and fast
  # - enabled for capslock too
  xkbset repeatkeys rate 280 14
  xkbset repeatkeys 66
  xkbset repeatkeys 22

  # Enable sticky keys.
  xkbset exp 1 \=sticky \=twokey \=latchlock
  xkbset sticky -twokey -latchlock

  numlockx off
fi

# Detect and configure Razer mouses.
if [ 0 -ne $opt_mouse ] && which razercfg 2>/dev/null 1>&2
then
  razercfg -s |
  while IFS=':' read type model dev
  do
    if [ 'Mouse' != "$type" ]
    then
      continue
    fi

    setrazer "$model" "$dev"
  done
fi

if [ 0 -ne $opt_test ]
then
  xmodmap -pm &&
  xev -event keyboard -event mouse |
  sed -n '/^\(\(Key\|Button\)\(Press\|Release\)\)\>.*/!d;s//\1/p;:_loop;n;/^$/d;/^\s*\(state\|XLookupString\)\>/{s/\(^\|,\)\s*same_screen[^,]*\(,\|$\)//;p};b_loop'
fi

# vim: foldmethod=marker foldlevel=0
