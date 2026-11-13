#!/usr/bin/env bash
# =============================================================================
#  Serpantinum Infinite Desktop - installer TUI
#  Card based terminal UI: administrator password -> update progress -> result.
#  Same look and feel as the Whitelily / Moonlight theme installers.
#  Sourced by install.sh; everything here is prefixed or uniquely named so it
#  can live next to the classic text installer (ui.sh).
# =============================================================================

THEME_NAME="Serpantinum"
BANNER_TITLE="SERPANTINUM"

# Gradient stops ("r g b") used for the banner, borders, dividers and progress bar
GRADIENT_STOPS=(
  "72 132 255"
  "98 190 255"
  "142 232 255"
  "226 247 255"
)

# Full-size logo (83 columns) and a slimmer one (71 columns) for narrower terminals
BANNER_WIDE=(
  '██████ ██████ █████  █████   ████  ██  ██ ██████ ██████ ██  ██ ██  ██ ██  ██'
  '██     ██     ██  ██ ██  ██ ██  ██ ███ ██   ██     ██   ███ ██ ██  ██ ██████'
  '██████ ████   █████  █████  ██████ ██████   ██     ██   ██████ ██  ██ ██████'
  '    ██ ██     ██ ██  ██     ██  ██ ██ ███   ██     ██   ██ ███ ██  ██ ██  ██'
  '    ██ ██     ██  ██ ██     ██  ██ ██  ██   ██     ██   ██  ██ ██  ██ ██  ██'
  '██████ ██████ ██  ██ ██     ██  ██ ██  ██   ██   ██████ ██  ██  ████  ██  ██'
)

BANNER_THIN=(
  ' ████ █████ ████  ████   ███  █   █ █████ █████ █   █ █   █ █   █'
  '█     █     █   █ █   █ █   █ ██  █   █     █   ██  █ █   █ ██ ██'
  ' ███  ████  ████  ████  █████ █ █ █   █     █   █ █ █ █   █ █ █ █'
  '    █ █     █  █  █     █   █ █  ██   █     █   █  ██ █   █ █   █'
  '████  █████ █   █ █     █   █ █   █   █   █████ █   █  ███  █   █'
)

BANNER=("${BANNER_WIDE[@]}")

# The UI relies on box-drawing / block glyphs
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
  *[Uu][Tt][Ff]-8*|*[Uu][Tt][Ff]8*) : ;;
  *) export LC_ALL=C.UTF-8 ;;
esac

HOME_DIR="${HOME}"
USER_NAME="${USER_NAME:-$(whoami)}"
LOG_DIR="${XDG_STATE_HOME:-${HOME_DIR}/.local/state}/serpantinum-installer"
LOGFILE=""; NOTE_FILE=""; STATE_FILE=""

tui_init_logs() {
  mkdir -p "$LOG_DIR" 2>/dev/null || LOG_DIR="${TMPDIR:-/tmp}"
  LOGFILE="${LOG_DIR}/install-$(date +%Y%m%d-%H%M%S).log"
  : > "$LOGFILE" 2>/dev/null || LOGFILE="$(mktemp)"
  NOTE_FILE="$(mktemp)"; STATE_FILE="$(mktemp)"
  printf 'Serpantinum installer  %s\nuser=%s\n' "$(date)" "$USER_NAME" >> "$LOGFILE"
}

# One-line result a step can report on the final screen
tui_note() { printf '%s\n' "$*" > "$NOTE_FILE"; }

# =============================================================================
#  COLOUR ENGINE
#  A tonal blue palette in the spirit of Material You (surface elevations,
#  primary / container / on-container roles, a tertiary accent) - but with
#  harmonised semantic colours and true multi-stop gradients.
# =============================================================================
TRUECOLOR=false
case "${COLORTERM:-}" in *truecolor*|*24bit*) TRUECOLOR=true ;; esac
case "${TERM:-}" in *-direct|*kitty*|*alacritty*|*wezterm*|foot*) TRUECOLOR=true ;; esac

# Surfaces: each step up is slightly lighter, tinted toward the seed hue
P_BG="8 12 24"          # page            (surface dim)
P_LOW="11 17 32"        # recessed wells  (surface lowest)
P_CARD="16 24 44"       # card            (surface container)
P_HIGH="28 40 72"       # chips, tracks   (surface container high)
P_OUTLINE="46 62 112"   # borders         (outline variant)
# Roles
P_ACCENT="122 166 255"  # primary, strong
P_PRIMARY="170 198 255" # primary, soft
P_PCONT="32 56 120"     # primary container
P_ONPCONT="218 229 255" # on primary container
P_TEXT="228 234 250"    # on surface
P_MUTED="141 154 192"   # on surface variant
P_SUBTLE="86 100 146"   # disabled / hints
P_SECOND="124 214 245"  # secondary (cyan)
P_TERTIARY="208 192 255" # tertiary (lavender)
P_TCONT="64 50 116"     # tertiary container
# Semantic - hue-shifted toward blue so they sit naturally in the palette
P_SUCCESS="124 227 195"
P_WARN="255 213 138"
P_ERROR="255 143 166"
P_ECONT="72 24 44"       # error container   (wrong password field)
P_SCONT="20 66 56"       # success container (access granted field)
PALETTE_TOKENS=(BG LOW CARD HIGH OUTLINE ACCENT PRIMARY PCONT ONPCONT TEXT MUTED SUBTLE SECOND TERTIARY TCONT SUCCESS WARN ERROR ECONT SCONT)

rgb_idx() { REPLY=$(( 16 + 36 * (($1 * 5 + 127) / 255) + 6 * (($2 * 5 + 127) / 255) + (($3 * 5 + 127) / 255) )); }
mk_fg() { if $TRUECOLOR; then REPLY=$'\e[38;2;'"$1;$2;$3"m; else rgb_idx "$1" "$2" "$3"; REPLY=$'\e[38;5;'"${REPLY}"m; fi; }
mk_bg() { if $TRUECOLOR; then REPLY=$'\e[48;2;'"$1;$2;$3"m; else rgb_idx "$1" "$2" "$3"; REPLY=$'\e[48;5;'"${REPLY}"m; fi; }

init_palette() {
  local t v
  for t in "${PALETTE_TOKENS[@]}"; do
    v="P_$t"; set -- ${!v}
    mk_fg "$1" "$2" "$3"; printf -v "F_$t" '%s' "$REPLY"
    mk_bg "$1" "$2" "$3"; printf -v "B_$t" '%s' "$REPLY"
  done
  BOLD=$'\e[1m'
  R0=$'\e[0m'"${B_BG}"                         # reset -> page background
  RS=$'\e[0m'"${B_CARD}${F_TEXT}"              # reset -> card surface
  ICON_OK="✓"; ICON_FAIL="✗"; ICON_WARN="!"; ICON_SKIP="–"; ICON_QUEUE="○"
}

init_palette_plain() {
  local t
  for t in "${PALETTE_TOKENS[@]}"; do printf -v "F_$t" '%s' ''; printf -v "B_$t" '%s' ''; done
  BOLD=''; R0=''; RS=''
  ICON_OK="[ok]"; ICON_FAIL="[x]"; ICON_WARN="[!]"; ICON_SKIP="[-]"; ICON_QUEUE="[ ]"
}

# gradient position (0..1000) -> GR GG GB
grad_rgb() {
  local t=$1 n=$(( ${#GRADIENT_STOPS[@]} - 1 )) sc seg f
  (( t < 0 )) && t=0
  (( t > 1000 )) && t=1000
  sc=$(( t * n )); seg=$(( sc / 1000 )); (( seg >= n )) && seg=$(( n - 1 ))
  f=$(( sc - seg * 1000 ))
  local -a a=(${GRADIENT_STOPS[seg]}) b=(${GRADIENT_STOPS[seg + 1]})
  GR=$(( a[0] + (b[0] - a[0]) * f / 1000 ))
  GG=$(( a[1] + (b[1] - a[1]) * f / 1000 ))
  GB=$(( a[2] + (b[2] - a[2]) * f / 1000 ))
}

# gradient_str TEXT [OFFSET] [SPAN]  ->  REPLY  (per-character foreground gradient)
gradient_str() {
  local s=$1 off=${2:-0} span=${3:-${#1}} out='' ch i t
  (( span < 2 )) && span=2
  for (( i = 0; i < ${#s}; i++ )); do
    ch=${s:i:1}
    if [[ $ch == ' ' ]]; then out+=' '; continue; fi
    t=$(( (i + off) * 1000 / (span - 1) ))
    grad_rgb "$t"; mk_fg "$GR" "$GG" "$GB"
    out+="${REPLY}${ch}"
  done
  REPLY=$out
}

# Smooth progress bar with 1/8-cell resolution.  bar PERMILLE WIDTH -> REPLY
PARTIAL=("" "▏" "▎" "▍" "▌" "▋" "▊" "▉")
bar() {
  local pm=$1 w=$2 e full rem i out="${B_HIGH}" sp
  (( pm > 1000 )) && pm=1000
  e=$(( pm * w * 8 / 1000 )); full=$(( e / 8 )); rem=$(( e % 8 ))
  for (( i = 0; i < full; i++ )); do
    grad_rgb $(( i * 1000 / (w - 1) )); mk_fg "$GR" "$GG" "$GB"; out+="${REPLY}█"
  done
  i=$full
  if (( rem > 0 && full < w )); then
    grad_rgb $(( full * 1000 / (w - 1) )); mk_fg "$GR" "$GG" "$GB"; out+="${REPLY}${PARTIAL[rem]}"; i=$(( full + 1 ))
  fi
  printf -v sp '%*s' $(( w - i )) ''
  REPLY="${out}${sp}${RS}"
}

# -----------------------------------------------------------------------------
# Text helpers (all set REPLY)
# -----------------------------------------------------------------------------
strip_sgr() {   # drop colour escapes from untrusted text (log lines)
  local s=$1 out=''
  while [[ $s == *$'\e'* ]]; do out+=${s%%$'\e'*}; s=${s#*$'\e'}; s=${s#*[A-Za-z]}; done
  REPLY=${out}${s}
}
# visible width of a string containing SGR escapes (loop form: the ${//} extglob
# variant is catastrophically slow on colour-dense strings)
vlen() {
  local s=$1 n=0 c
  while [[ $s == *$'\e'* ]]; do
    c=${s%%$'\e'*}; n=$(( n + ${#c} ))
    s=${s#*$'\e'}; s=${s#*m}
  done
  REPLY=$(( n + ${#s} ))
}
rep()    { local s; printf -v s '%*s' "$2" ''; REPLY=${s// /$1}; }
spaces() { printf -v REPLY '%*s' "$1" ''; }
trunc()  { if (( ${#1} > $2 )); then REPLY="${1:0:$2-1}…"; else REPLY=$1; fi; }
padr()   { local sp; printf -v sp '%*s' $(( $2 - ${#1} )) ''; REPLY="${1}${sp}"; }
center() { local v sp; vlen "$1"; v=$REPLY; spaces $(( (IW - v) / 2 > 0 ? (IW - v) / 2 : 0 )); REPLY="${REPLY}${1}"; }
lr()     { local a b g sp; vlen "$1"; a=$REPLY; vlen "$2"; b=$REPLY; g=$(( IW - a - b )); (( g < 1 )) && g=1; spaces "$g"; REPLY="${1}${REPLY}${2}"; }
pad_to() { local v; vlen "$1"; v=$REPLY; (( v >= $2 )) && { REPLY=$1; return; }; spaces $(( $2 - v )); REPLY="${1}${REPLY}"; }
track()  { local s=$1 out='' i ch; for (( i = 0; i < ${#s}; i++ )); do ch=${s:i:1}; [[ $ch == ' ' ]] && out+='  ' || out+="${ch} "; done; REPLY=${out% }; }
fmt_ms() { printf -v REPLY '%d.%ds' $(( $1 / 1000 )) $(( $1 % 1000 / 100 )); }

wrap_text() {   # wrap_text TEXT WIDTH -> WRAPPED[]
  local -a words; local line='' w
  WRAPPED=(); read -ra words <<< "$1"
  for w in "${words[@]}"; do
    if [[ -z $line ]]; then line=$w
    elif (( ${#line} + 1 + ${#w} <= $2 )); then line+=" $w"
    else WRAPPED+=("$line"); line=$w; fi
  done
  [[ -n $line ]] && WRAPPED+=("$line")
  return 0
}

# =============================================================================
#  TERMINAL / CARD RENDERER
# =============================================================================
UI_ACTIVE=false; RESIZED=1; ROWS=24; COLS=80; PAD=3; LAST_GEOM=""
MIN_COLS=56; MIN_ROWS=18
FRAME=(); OUT=""; CARD_TOP=1
STTY_SAVED=""

get_size() {
  local sz; sz=$(stty size 2>/dev/null) || sz=""
  if [[ $sz =~ ^([0-9]+)\ ([0-9]+)$ ]]; then ROWS=${BASH_REMATCH[1]}; COLS=${BASH_REMATCH[2]}
  else ROWS=${LINES:-24}; COLS=${COLUMNS:-80}; fi
}

layout() {
  W=$(( COLS - 4 )); (( W > 88 )) && W=88
  IW=$(( W - 2 - 2 * PAD ))
  CX=$(( (COLS - W) / 2 + 1 ))
  printf -v PADSTR '%*s' "$PAD" ''
}

# Pre-render the gradient pieces that only change with the terminal size
build_static() {
  local l
  rep '─' $(( W - 2 )); gradient_str "$REPLY"
  TOPB="${B_CARD}${F_OUTLINE}╭${REPLY}${F_OUTLINE}╮${R0}"
  rep '─' $(( W - 2 )); BOTB="${B_CARD}${F_OUTLINE}╰${REPLY}╯${R0}"
  rep '─' "$IW"; gradient_str "$REPLY"; DIV="${REPLY}${RS}"

  BANNER=("${BANNER_WIDE[@]}"); BANNER_W=0
  for l in "${BANNER[@]}"; do (( ${#l} > BANNER_W )) && BANNER_W=${#l}; done
  if (( IW < BANNER_W + 2 )); then BANNER=("${BANNER_THIN[@]}"); BANNER_W=0; fi
  for l in "${BANNER[@]}"; do (( ${#l} > BANNER_W )) && BANNER_W=${#l}; done
  SHOW_BANNER=false; SHOW_INFO=false; SHOW_CRUMBS=false
  (( ROWS >= 34 && IW >= 44 )) && SHOW_CRUMBS=true
  (( ROWS >= 25 + ${#BANNER[@]} && IW >= BANNER_W + 2 )) && SHOW_BANNER=true
  $SHOW_BANNER && (( ROWS >= 27 + ${#BANNER[@]} )) && SHOW_INFO=true

  INTRO_K=-1; render_banner
  track "${BANNER_TITLE^^}"; gradient_str "$REPLY"; center "${BOLD}${REPLY}${RS}"; TITLE_R=$REPLY
  # subtitle: tracked caps + credit, degrading gracefully on narrow cards
  local sub; track "INFINITE DESKTOP INSTALLER"; sub=$REPLY
  if (( ${#sub} + 11 <= IW )); then
    gradient_str "$sub" 0 $(( ${#sub} + 10 )); SUB_G=$REPLY
    center "${SUB_G}${RS}${F_SUBTLE}   ·   ${F_MUTED}CSSKY${RS}"
  else
    sub="Infinite Desktop installer"; gradient_str "$sub"; center "${REPLY}${RS}"
  fi
  SUB_R=$REPLY
}

# Render BANNER into BANNER_R[]; INTRO_K >= 0 shows only the first K columns (wipe-in)
render_banner() {
  local i l vis pad
  BANNER_R=()
  for (( i = 0; i < ${#BANNER[@]}; i++ )); do
    l=${BANNER[i]}
    spaces $(( (IW - ${#l}) / 2 > 0 ? (IW - ${#l}) / 2 : 0 )); pad=$REPLY
    vis=$l; (( INTRO_K >= 0 )) && vis=${l:0:INTRO_K}
    gradient_str "$vis" $(( i * 4 )) $(( BANNER_W + 14 ))
    BANNER_R+=("${pad}${BOLD}${REPLY}${RS}")
  done
}

handle_resize() {
  (( RESIZED )) || return 0
  RESIZED=0; get_size; layout; build_static; LAST_GEOM=''
}

paint_bg() {
  local r blank; printf -v blank '%*s' "$COLS" ''
  OUT+="${R0}"$'\e[H'
  for (( r = 1; r <= ROWS; r++ )); do OUT+=$'\e['"${r};1H${blank}"; done
}

put_line() {   # put_line ROW CONTENT
  (( $1 > ROWS )) && return
  local v sp pad
  vlen "$2"; v=$REPLY; pad=$(( IW - v )); (( pad < 0 )) && pad=0
  printf -v sp '%*s' "$pad" ''
  OUT+=$'\e['"$1;${CX}H${B_CARD}${F_OUTLINE}│${RS}${PADSTR}${2}${RS}${sp}${PADSTR}${F_OUTLINE}│${R0}"
}

draw_too_small() {
  local m1="Terminal too small" m2="need ${MIN_COLS}x${MIN_ROWS}  ·  now ${COLS}x${ROWS}" r=$(( ROWS / 2 ))
  OUT=$'\e[?2026h'; paint_bg
  (( r < 1 )) && r=1
  OUT+=$'\e['"${r};$(( (COLS - ${#m1}) / 2 + 1 > 0 ? (COLS - ${#m1}) / 2 + 1 : 1 ))H${B_BG}${F_WARN}${BOLD}${m1}"
  OUT+=$'\e['"$(( r + 1 ));$(( (COLS - ${#m2}) / 2 + 1 > 0 ? (COLS - ${#m2}) / 2 + 1 : 1 ))H${B_BG}${F_MUTED}${m2}"
  printf '%s' "${OUT}${R0}"$'\e[?2026l'
  LAST_GEOM=''
}

flush_card() {
  if (( COLS < MIN_COLS || ROWS < MIN_ROWS )); then draw_too_small; return; fi
  local n=${#FRAME[@]} h top row i geom
  h=$(( n + 4 )); top=$(( (ROWS - h) / 2 + 1 )); (( top < 1 )) && top=1
  CARD_TOP=$top
  OUT=$'\e[?2026h'
  geom="${ROWS}x${COLS}/${top}/${h}"
  if [[ $geom != "$LAST_GEOM" ]]; then paint_bg; LAST_GEOM=$geom; fi
  row=$top
  OUT+=$'\e['"${row};${CX}H${TOPB}"; row=$(( row + 1 ))
  put_line "$row" ""; row=$(( row + 1 ))
  for (( i = 0; i < n; i++ )); do put_line "$row" "${FRAME[i]}"; row=$(( row + 1 )); done
  put_line "$row" ""; row=$(( row + 1 ))
  (( row <= ROWS )) && OUT+=$'\e['"${row};${CX}H${BOTB}"
  printf '%s' "${OUT}${R0}"$'\e[?2026l'
}

# -----------------------------------------------------------------------------
# Keyboard
# -----------------------------------------------------------------------------
KEY=""
tkey() {   # returns 1 on timeout
  local k rest
  KEY=""
  if IFS= read -rsn1 -t "${1:-0.25}" k; then
    case $k in
      '')     KEY=ENTER ;;
      ' ')    KEY=SPACE ;;
      $'\e')  if IFS= read -rsn2 -t 0.02 rest; then
                case $rest in
                  '[A'|'OA') KEY=UP ;;   '[B'|'OB') KEY=DOWN ;;
                  '[C'|'OC') KEY=RIGHT ;; '[D'|'OD') KEY=LEFT ;;
                  *) KEY=OTHER ;;
                esac
              else KEY=ESC; fi ;;
      *)      KEY=$k ;;
    esac
    return 0
  fi
  return 1
}
drain_keys() { while IFS= read -rsn1 -t 0.01 _; do :; done; }

# -----------------------------------------------------------------------------
# Reusable frame pieces
# -----------------------------------------------------------------------------
add_hints() {   # add_hints "key|label" ...
  local line='' used=0 p k l w
  for p in "$@"; do
    k=${p%%|*}; l=${p#*|}; w=$(( ${#k} + 2 + 1 + ${#l} + 2 ))
    if (( used + w - 2 > IW )) && [[ -n $line ]]; then FRAME+=("${line%  }"); line=''; used=0; fi
    line+="${B_HIGH}${F_PRIMARY} ${k} ${RS} ${F_MUTED}${l}${RS}  "; used=$(( used + w ))
  done
  [[ -n $line ]] && FRAME+=("${line%  }")
  return 0
}

add_title() {   # add_title TEXT [RIGHT] [LEADING-GLYPH]
  gradient_str "$1" 0 $(( ${#1} + 2 ))
  local left="${3:-}${BOLD}${REPLY}${RS}"
  if [[ -n ${2:-} ]]; then lr "$left" "${F_MUTED}$2${RS}"; FRAME+=("$REPLY"); else FRAME+=("$left"); fi
  FRAME+=("$DIV")
}

add_header() {   # logo / title block shared by the select screen
  local l
  if $SHOW_BANNER; then
    for l in "${BANNER_R[@]}"; do FRAME+=("$l"); done
    FRAME+=("" "$SUB_R")
  else
    FRAME+=("$TITLE_R" "$SUB_R")
  fi
}

# -----------------------------------------------------------------------------
# Wizard progress:  Options › Access › Update › Done
# -----------------------------------------------------------------------------
TUI_NOUN="Update"; TUI_VERB="Updating"

tui_set_verb() {
  if [[ ${IS_REINSTALL:-false} == true ]]; then TUI_NOUN="Reinstall"; TUI_VERB="Reinstalling"
  elif [[ ${INSTALL_STATE:-fresh} == current ]]; then TUI_NOUN="Update"; TUI_VERB="Updating"
  else TUI_NOUN="Install"; TUI_VERB="Installing"; fi
}

add_crumbs() {   # add_crumbs options|access|update|done
  $SHOW_CRUMBS || return 0
  local cur=$1 id lab line='' plain=0 pos=past
  for id in options access update done; do
    case $id in options) lab=Options ;; access) lab=Access ;; update) lab=$TUI_NOUN ;; done) lab=Done ;; esac
    if [[ $id == "$cur" ]]; then
      pos=now; line+="${F_ACCENT}● ${BOLD}${F_TEXT}${lab}${RS}"; plain=$(( plain + 2 + ${#lab} ))
    else
      [[ $pos == now ]] && pos=future
      if [[ $pos == past ]]; then line+="${F_SUCCESS}${lab}${RS}"; else line+="${F_SUBTLE}${lab}${RS}"; fi
      plain=$(( plain + ${#lab} ))
    fi
    if [[ $id != done ]]; then line+="${F_SUBTLE} › ${RS}"; plain=$(( plain + 3 )); fi
  done
  (( plain > IW )) && return 0
  FRAME+=("$line" "")
}

# =============================================================================
#  Privileges  -  administrator password screen
#  The installer reads the password itself (masked, inside the card) and hands
#  it to `sudo -S`, so sudo never prints its own prompt over the UI.
# =============================================================================
HAVE_ROOT=true; KEEPALIVE_PID=""; PW_MAX=3
SPIN=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏); LOG_TAIL=(); CUR_PID=""

tui_keepalive() {
  (( EUID == 0 )) && return 0
  [[ -n $KEEPALIVE_PID ]] && kill "$KEEPALIVE_PID" 2>/dev/null
  ( while true; do sudo -n -v 2>/dev/null || exit; sleep 45; kill -0 "$$" 2>/dev/null || exit; done ) &>/dev/null &
  KEEPALIVE_PID=$!
}

build_pw_frame() {   # $1 length  $2 caret  $3 margin  $4 state  $5 message  $6 tick  $7 tries
  local n=$1 caret=$2 m=$3 st=$4 msg=$5 tick=${6:-0} tries=${7:-0}
  local ww=$(( IW - 6 )) cap dots='' ic bgc well blank body mg status cg
  FRAME=()
  add_crumbs access
  add_title "Administrator access" "" "${F_TERTIARY}◆ "
  FRAME+=("" "${F_TEXT}Administrator access is needed to:${RS}")
  FRAME+=("${F_SECOND}•${F_TEXT} install and update system packages${RS}")
  FRAME+=("${F_SECOND}•${F_TEXT} write login screen, service and shell files${RS}")
  FRAME+=("")
  if (( tries > 0 )); then lr "${F_MUTED}password for ${F_TEXT}${USER_NAME}${RS}" "${F_SUBTLE}attempt $(( tries < PW_MAX ? tries + 1 : PW_MAX )) of ${PW_MAX}${RS}"
  else REPLY="${F_MUTED}password for ${F_TEXT}${USER_NAME}${RS}"; fi
  FRAME+=("$REPLY")
  case $st in
    error)    bgc=$B_ECONT; ic="${F_ERROR}${ICON_FAIL}" ;;
    ok)       bgc=$B_SCONT; ic="${F_SUCCESS}${ICON_OK}" ;;
    checking) bgc=$B_LOW;   ic="${F_ACCENT}${SPIN[tick % ${#SPIN[@]}]}" ;;
    *)        bgc=$B_LOW;   ic="${F_ACCENT}❯" ;;
  esac
  cap=$(( ww - 6 )); (( cap < 4 )) && cap=4
  if (( n > cap )); then rep '●' "$cap"; else rep '●' "$n"; fi
  dots=$REPLY
  cg=" "; (( caret )) && [[ $st == idle || $st == error ]] && cg="${F_ACCENT}▏"
  if (( n == 0 )) && [[ $st == idle || $st == error ]]; then body="${cg}${F_SUBTLE}type your password"
  else body="${F_PRIMARY}${dots}${cg}"; fi
  [[ $st == ok ]] && body="${F_SUCCESS}${dots}"
  pad_to "${bgc}" "$ww"; blank=$REPLY
  pad_to "${bgc} ${ic}  ${body}" "$ww"; well=$REPLY
  spaces "$m"; mg=$REPLY
  FRAME+=("${mg}${blank}${RS}" "${mg}${well}${RS}" "${mg}${blank}${RS}")
  case $st in
    checking) status="${F_SECOND}${SPIN[tick % ${#SPIN[@]}]}${F_MUTED} Verifying…" ;;
    ok)       status="${F_SUCCESS}${ICON_OK} Access granted" ;;
    *)        if [[ -n $msg ]]; then trunc "$msg" $(( IW - 2 )); status="${F_ERROR}${ICON_FAIL} ${REPLY}"
              else status="${F_MUTED}Enter your password to continue."; fi ;;
  esac
  FRAME+=("" "${status}${RS}" "")
  add_hints "↵|unlock" "esc|cancel" "ctrl-c|quit"
}

# returns 0 granted · 1 cancelled · 2 refused / no sudo
tui_access() {
  HAVE_ROOT=true
  (( EUID == 0 )) && return 0
  command -v sudo &>/dev/null || return 2
  if sudo -n true 2>/dev/null; then tui_keepalive; return 0; fi
  local pw='' tries=0 state=idle msg='' caret=1 dirty=1 tick=0 m=2 rc pid errf sh
  errf=$(mktemp)
  drain_keys
  while true; do
    (( RESIZED )) && { handle_resize; dirty=1; }
    if (( dirty )); then build_pw_frame "${#pw}" "$caret" "$m" "$state" "$msg" "$tick" "$tries"; flush_card; dirty=0; fi
    if ! tkey 0.45; then caret=$(( 1 - caret )); dirty=1; continue; fi
    caret=1; dirty=1
    case $KEY in
      ENTER)
        if [[ -z $pw ]]; then state=error; msg="Type your password first"; continue; fi
        state=checking; msg=''
        ( printf '%s\n' "$pw" | sudo -S -v -p '' ) >/dev/null 2>"$errf" &
        pid=$!; CUR_PID=$pid
        while kill -0 "$pid" 2>/dev/null; do
          handle_resize
          build_pw_frame "${#pw}" 0 "$m" checking '' "$tick" "$tries"; flush_card
          tick=$(( tick + 1 )); sleep 0.07
        done
        wait "$pid"; rc=$?; CUR_PID=""
        if (( rc == 0 )); then
          printf '\n[admin] sudo authentication ok\n' >> "$LOGFILE"
          build_pw_frame "${#pw}" 0 2 ok '' "$tick" "$tries"; flush_card; sleep 0.6
          pw=''; rm -f "$errf"; tui_keepalive; return 0
        fi
        pw=''
        if grep -qiE 'not in the sudoers|may not run sudo|not allowed to' "$errf" 2>/dev/null; then
          printf '\n[admin] sudo refused: this account may not use sudo\n' >> "$LOGFILE"
          build_pw_frame 0 0 2 error "This account is not allowed to use sudo" "$tick" "$tries"; flush_card; sleep 1.8
          rm -f "$errf"; return 2
        fi
        tries=$(( tries + 1 ))
        printf '\n[admin] sudo authentication failed (attempt %d of %d)\n' "$tries" "$PW_MAX" >> "$LOGFILE"
        if (( tries >= PW_MAX )); then msg="Too many attempts"; else msg="Incorrect password · $(( PW_MAX - tries )) attempt(s) left"; fi
        state=error
        for sh in 4 0 4 1 3 2; do build_pw_frame 0 0 "$sh" error "$msg" "$tick" "$tries"; flush_card; sleep 0.035; done
        if (( tries >= PW_MAX )); then sleep 1.4; rm -f "$errf"; return 2; fi
        drain_keys
        ;;
      ESC)  pw=''; rm -f "$errf"; return 1 ;;
      $'\x7f'|$'\b') pw=${pw%?}; state=idle ;;
      $'\x15')       pw=''; state=idle ;;
      SPACE)         pw+=' '; state=idle ;;
      UP|DOWN|LEFT|RIGHT|OTHER) ;;
      *)    if (( ${#KEY} == 1 )) && [[ $KEY == [[:print:]] ]]; then pw+=$KEY; state=idle; fi ;;
    esac
  done
}

# =============================================================================
#  Log tail + status helpers (shared by the busy and update screens)
# =============================================================================
refresh_log_tail() {
  local l clean=() line
  while IFS= read -r l; do
    strip_sgr "$l"; line=${REPLY//$'\r'/}; line=${line//$'\t'/ }
    [[ -z ${line// /} ]] && continue
    clean+=("$line")
  done < <(tail -n 14 "$LOGFILE" 2>/dev/null)
  LOG_TAIL=()
  local n=${#clean[@]} s=$(( ${#clean[@]} > 4 ? ${#clean[@]} - 4 : 0 ))
  for (( l = s; l < n; l++ )); do LOG_TAIL+=("${clean[l]}"); done
}

status_icon() {   # status_icon STATE TICK -> REPLY
  case $1 in
    queued)  REPLY="${F_SUBTLE}${ICON_QUEUE}" ;;
    running) REPLY="${F_ACCENT}${SPIN[$2 % ${#SPIN[@]}]}" ;;
    ok)      REPLY="${F_SUCCESS}${ICON_OK}" ;;
    warn)    REPLY="${F_WARN}${ICON_WARN}" ;;
    skip)    REPLY="${F_MUTED}${ICON_SKIP}" ;;
    fail)    REPLY="${F_ERROR}${ICON_FAIL}" ;;
  esac
}

add_log_box() {   # four-line recessed well showing the tail of the log
  local l
  for (( l = 0; l < 4; l++ )); do
    if (( l < ${#LOG_TAIL[@]} )); then trunc "${LOG_TAIL[l]}" $(( IW - 4 )); pad_to "${B_LOW}${F_SUBTLE} › ${F_MUTED}${REPLY}" "$IW"
    else pad_to "${B_LOW}${F_SUBTLE} ›" "$IW"; fi
    FRAME+=("${REPLY}${RS}")
  done
}

# Quick card used between screens: spinner + title + live log tail
build_busy_frame() {   # $1 title  $2 note  $3 tick
  FRAME=()
  add_crumbs access
  add_title "$1" ""
  FRAME+=("${F_ACCENT}${SPIN[$3 % ${#SPIN[@]}]} ${F_TEXT}$2${RS}" "")
  add_log_box
  FRAME+=("")
  trunc "log  ${LOGFILE/#$HOME_DIR/\~}" "$IW"; FRAME+=("${F_SUBTLE}${REPLY}${RS}")
}

tui_busy() {   # tui_busy TITLE NOTE FUNCTION   (runs FUNCTION in the background, log -> file)
  local title=$1 note=$2 fn=$3 pid rc tick=0
  printf '\n══ %s ══\n' "$title" >> "$LOGFILE"
  ( set -e; "$fn" ) >> "$LOGFILE" 2>&1 < /dev/null &
  pid=$!; CUR_PID=$pid
  while kill -0 "$pid" 2>/dev/null; do
    handle_resize
    (( tick % 3 == 0 )) && refresh_log_tail
    build_busy_frame "$title" "$note" "$tick"; flush_card
    tick=$(( tick + 1 )); sleep 0.07
  done
  wait "$pid"; rc=$?; CUR_PID=""
  return $rc
}

tui_status() {   # one static frame, for quick in-process work
  LOG_TAIL=(); build_busy_frame "$1" "$2" 0; flush_card
}

# =============================================================================
#  SCREEN 1 - options
#  The same choices as the classic menu (packages, compositor, SDDM, wallpapers,
#  telemetry) in the card UI.  The three detail pickers still use the classic
#  full-screen helpers; the card pauses while they run.
# =============================================================================
MENU_L=(); MENU_V=(); MENU_K=(); MENU_H=(); UI_MSG=""

tui_pause()  { printf '\e[?25h'; stty echo 2>/dev/null; printf '\e[0m\e[2J\e[H'; }
tui_resume() { printf '\e[?25l'; stty -echo 2>/dev/null; RESIZED=1; LAST_GEOM=''; }

menu_items() {
  local c v
  MENU_L=(); MENU_V=(); MENU_K=(); MENU_H=()
  MENU_L+=("Package overview"); MENU_V+=("${#REQUIRED_PKGS[@]} packages"); MENU_K+=(pkgs)
  MENU_H+=("Browse every package and see what is missing")
  if (( ${#SELECTED_COMPOSITORS[@]} )); then c=$(IFS=,; echo "${SELECTED_COMPOSITORS[*]}"); else c="choose one"; fi
  MENU_L+=("Target compositor"); MENU_V+=("$c"); MENU_K+=(comp)
  MENU_H+=("Hyprland, Niri, Sway or Mango - the one Serpantinum is set up for")
  v=OFF; [[ $OPT_SDDM == true ]] && v=ON
  MENU_L+=("SDDM login screen"); MENU_V+=("$v"); MENU_K+=(sddm)
  MENU_H+=("Install the Serpantinum login theme (needs administrator access)")
  v="3 random"; [[ $INSTALL_FULL_WALLPAPERS == true ]] && v="Full pack"
  MENU_L+=("Wallpapers"); MENU_V+=("$v"); MENU_K+=(wall)
  MENU_H+=("Space toggles between the full wallpaper pack and 3 random ones")
  v=OFF; [[ $ENABLE_TELEMETRY == true ]] && v=ON
  MENU_L+=("Telemetry"); MENU_V+=("$v"); MENU_K+=(tele)
  MENU_H+=("Anonymous install counter - space toggles it")
  if [[ ${INSTALL_STATE:-fresh} == current ]]; then
    MENU_L+=("Update"); MENU_V+=("${OLD_VERSION:-?} → ${TARGET_VERSION}"); MENU_K+=(go)
    MENU_H+=("Update Serpantinum and keep your settings")
    MENU_L+=("Reinstall"); MENU_V+=("clean redeploy"); MENU_K+=(redo)
    MENU_H+=("Redeploy every file from scratch (backups are kept)")
  else
    MENU_L+=("Install"); MENU_V+=("${TARGET_VERSION}"); MENU_K+=(go)
    MENU_H+=("Install Serpantinum Infinite Desktop")
  fi
  MENU_L+=("Exit"); MENU_V+=(""); MENU_K+=(quit)
  MENU_H+=("Leave without changing anything")
}

menu_row() {   # menu_row INDEX FOCUS -> REPLY
  local i=$1 f=$2 bg mark fgl vc kind=${MENU_K[$1]} val=${MENU_V[$1]} left right
  if (( i == f )); then bg=$B_PCONT; mark="▸"; fgl=$F_ONPCONT; else bg=$B_CARD; mark=" "; fgl=$F_TEXT; fi
  vc=$F_MUTED; (( i == f )) && vc=$F_PRIMARY
  case $kind in
    sddm|tele) [[ $val == ON ]] && vc=$F_SUCCESS || vc=$F_SUBTLE ;;
    wall)      vc=$F_SECOND ;;
    comp)      (( ${#SELECTED_COMPOSITORS[@]} )) || vc=$F_WARN ;;
    go)        fgl=$F_SUCCESS; (( i == f )) && fgl=$F_SUCCESS ;;
    redo)      fgl=$F_WARN ;;
    quit)      fgl=$F_MUTED; (( i == f )) && fgl=$F_ONPCONT ;;
  esac
  left="${bg}${F_ACCENT}${mark} ${F_SUBTLE}$(( i + 1 ))  ${BOLD}${fgl}${MENU_L[i]}"
  right="${vc}${val} "
  lr "$left" "$right"
  REPLY="${REPLY}"
}

# System specs (user, OS, CPU, GPU, memory) - filled once
SPEC_L=(); SPEC_V=()
tui_specs_init() {
  local ram kern host
  ram=$(awk '/^MemTotal:/{printf "%.1f GB", $2/1048576}' /proc/meminfo 2>/dev/null)
  kern=$(uname -r 2>/dev/null); host=$(uname -n 2>/dev/null)
  SPEC_HOST="${USER_NAME}@${host:-localhost}"
  SPEC_L=(os cpu gpu memory kernel)
  SPEC_V=("${OS_NAME:-unknown}" "${CPU_INFO:-unknown}" "${GPU_INFO:-unknown}" "${ram:-unknown}" "${kern:-unknown}")
}

add_specs() {
  local i lab
  lr "${BOLD}${F_TEXT}System${RS}" "${F_MUTED}${SPEC_HOST}${RS}"; FRAME+=("$REPLY" "$DIV")
  for (( i = 0; i < ${#SPEC_L[@]}; i++ )); do
    padr "${SPEC_L[i]}" 8; lab=$REPLY
    trunc "${SPEC_V[i]}" $(( IW - 8 ))
    FRAME+=("${F_SUBTLE}${lab}${F_MUTED}${REPLY}${RS}")
  done
  FRAME+=("")
}

_menu_frame_body() {   # $1 focus  $2 with-specs (1/0)
  local f=$1 i n=${#MENU_L[@]} ver
  FRAME=()
  add_header
  FRAME+=("")
  add_crumbs options
  (( $2 )) && add_specs
  if [[ ${INSTALL_STATE:-fresh} == current ]]; then ver="installed ${OLD_VERSION:-?}  →  ${TARGET_VERSION}"
  else ver="version ${TARGET_VERSION}"; fi
  lr "${BOLD}${F_TEXT}Options${RS}" "${F_MUTED}${ver}${RS}"; FRAME+=("$REPLY" "$DIV")
  for (( i = 0; i < n; i++ )); do
    [[ ${MENU_K[i]} == go ]] && FRAME+=("")
    menu_row "$i" "$f"; FRAME+=("$REPLY")
  done
  FRAME+=("")
  if [[ -n $UI_MSG ]]; then FRAME+=("${F_WARN}${ICON_WARN} ${UI_MSG}${RS}")
  else trunc "${MENU_H[f]}" $(( IW - 2 )); FRAME+=("${F_SECOND}${REPLY}${RS}"); fi
  FRAME+=("")
  add_hints "↑↓|move" "↵|select" "space|toggle" "q|quit"
}

# Picks the richest layout that fits: banner + specs, banner, specs, neither
build_menu_frame() {   # $1 focus
  local f=$1 saved=$SHOW_BANNER v b sp
  for v in "1 1" "1 0" "0 1" "0 0"; do
    read -r b sp <<< "$v"
    SHOW_BANNER=$saved; [[ $b == 0 ]] && SHOW_BANNER=false
    _menu_frame_body "$f" "$sp"
    (( ${#FRAME[@]} + 4 <= ROWS )) && break
  done
  SHOW_BANNER=$saved
}


# =============================================================================
#  Card pickers: packages, compositors, SDDM  (replace the classic full-screen ones)
# =============================================================================
PK_NAME=(); PK_MISS=()

screen_packages() {
  local target=() missing_raw p c
  tui_status "Packages" "Checking installed packages…"
  target=("${REQUIRED_PKGS[@]}")
  for c in "${SELECTED_COMPOSITORS[@]}"; do target+=("$c"); done
  if [[ $OPT_SDDM == true ]]; then
    local sddm_pkgs=(); mapfile -t sddm_pkgs < <(sddm_packages); target+=("${sddm_pkgs[@]}")
  fi
  target+=("${PM_EXTRA_PKGS[@]}")
  missing_raw=$(pm_missing_pkgs "${target[@]}" 2>/dev/null)
  local -A miss=()
  while IFS= read -r p; do [[ -n $p ]] && miss["$p"]=1; done <<< "$missing_raw"
  PK_NAME=(); PK_MISS=()
  for p in "${target[@]}"; do PK_NAME+=("$p"); [[ -n ${miss[$p]:-} ]] && PK_MISS+=(1) || PK_MISS+=(0); done
  local n=${#PK_NAME[@]} nm=0 i top=0 cur=0 win dirty=1
  for (( i = 0; i < n; i++ )); do (( PK_MISS[i] )) && nm=$(( nm + 1 )); done
  while true; do
    (( RESIZED )) && { handle_resize; dirty=1; }
    win=$(( ROWS - 14 )); (( win > 20 )) && win=20; (( win < 3 )) && win=3; (( win > n )) && win=$n
    (( cur < top )) && top=$cur
    (( cur >= top + win )) && top=$(( cur - win + 1 ))
    if (( dirty )); then
      FRAME=(); add_crumbs options
      add_title "Packages" "${nm} missing  ·  ${n} total"
      for (( i = top; i < top + win && i < n; i++ )); do
        local bg=$B_CARD mk=" " ic lab
        (( i == cur )) && { bg=$B_PCONT; mk="▸"; }
        if (( PK_MISS[i] )); then ic="${F_ACCENT}+"; lab="${F_TEXT}${PK_NAME[i]}"; else ic="${F_SUCCESS}${ICON_OK}"; lab="${F_MUTED}${PK_NAME[i]}"; fi
        lr "${bg}${F_ACCENT}${mk} ${ic} ${lab}" "$( (( PK_MISS[i] )) && printf '%s' "${F_ACCENT}will be installed " || printf '%s' "${F_SUBTLE}installed " )"
        FRAME+=("$REPLY")
      done
      FRAME+=("" "${F_SUBTLE}$(( top + 1 ))-$(( top + win )) of ${n}${RS}" "")
      add_hints "↑↓|scroll" "↵|back"
      flush_card; dirty=0
    fi
    tkey 0.5 || continue
    dirty=1
    case $KEY in
      UP|k|K)   (( cur > 0 )) && cur=$(( cur - 1 )) ;;
      DOWN|j|J) (( cur < n - 1 )) && cur=$(( cur + 1 )) ;;
      ENTER|q|Q|ESC|SPACE) return 0 ;;
    esac
  done
}

CP_L=(Hyprland Niri Sway Mango); CP_ID=(hyprland niri sway mango); CP_INST=()

comp_selected() { [[ " ${SELECTED_COMPOSITORS[*]} " == *" $1 "* ]]; }

screen_compositors() {
  local i cursor=0 dirty=1 n=5 id pk
  CP_INST=()
  for (( i = 0; i < 4; i++ )); do
    id=${CP_ID[i]}; pk=$id; [[ $id == mango ]] && pk=$(compositor_package_name mango)
    if command -v "$id" &>/dev/null || pm_is_installed "$pk"; then CP_INST+=(1); else CP_INST+=(0); fi
  done
  while true; do
    (( RESIZED )) && { handle_resize; dirty=1; }
    if (( dirty )); then
      FRAME=(); add_crumbs options
      add_title "Target compositors" "${#SELECTED_COMPOSITORS[@]} selected"
      for (( i = 0; i < n; i++ )); do
        local bg=$B_CARD mk=" " fgl=$F_TEXT chk chkc st stc
        (( i == cursor )) && { bg=$B_PCONT; mk="▸"; fgl=$F_ONPCONT; }
        if (( i < 4 )); then
          if comp_selected "${CP_ID[i]}"; then chk="◉"; chkc=$F_ACCENT; else chk="○"; chkc=$F_SUBTLE; fi
          if (( CP_INST[i] )); then st="installed"; stc=$F_SUCCESS; else st="not installed"; stc=$F_SUBTLE; fi
          lr "${bg}${F_ACCENT}${mk} ${chkc}${chk} ${F_SUBTLE}$(( i + 1 ))  ${fgl}${CP_L[i]}" "${stc}${st} "
        else
          lr "${bg}${F_ACCENT}${mk}   ${F_SUBTLE}5  ${BOLD}${F_SUCCESS}Done" ""
        fi
        FRAME+=("$REPLY")
      done
      FRAME+=("" "${F_SECOND}Pick the compositor(s) Serpantinum is set up for${RS}" "")
      add_hints "↑↓|move" "space|toggle" "↵|select" "esc|done"
      flush_card; dirty=0
    fi
    tkey 0.5 || continue
    dirty=1
    case $KEY in
      UP|k|K)   cursor=$(( (cursor + n - 1) % n )) ;;
      DOWN|j|J) cursor=$(( (cursor + 1) % n )) ;;
      [1-4])    cursor=$(( KEY - 1 )); comp_toggle "${CP_ID[cursor]}" ;;
      5|q|Q|ESC) return 0 ;;
      ENTER|SPACE)
        if (( cursor == 4 )); then return 0; fi
        comp_toggle "${CP_ID[cursor]}" ;;
    esac
  done
}

comp_toggle() {
  if comp_selected "$1"; then remove_compositor "$1"; else SELECTED_COMPOSITORS+=("$1"); fi
}

screen_sddm() {
  local current_dm='' dm cursor=0 dirty=1 n i
  for dm in gdm gdm3 lightdm sddm lxdm lxdm-gtk3 ly; do
    if systemctl is-enabled "$dm.service" &>/dev/null || systemctl is-active "$dm.service" &>/dev/null; then current_dm=$dm; break; fi
  done
  local -a L V K
  while true; do
    L=(); V=(); K=()
    L+=("Install and configure SDDM"); V+=("$([[ $OPT_SDDM == true ]] && echo Enabled || echo Disabled)"); K+=(inst)
    if [[ -n $current_dm && $current_dm != sddm ]]; then
      L+=("Disable ${current_dm}"); V+=("$([[ $REPLACE_DM == true ]] && echo Yes || echo No)"); K+=(repl)
    fi
    L+=("Wayland backend"); V+=("$([[ $SDDM_WAYLAND == true ]] && echo Wayland || echo 'X11 / default')"); K+=(way)
    L+=("Done"); V+=(""); K+=(done)
    n=${#L[@]}; (( cursor >= n )) && cursor=$(( n - 1 ))
    (( RESIZED )) && { handle_resize; dirty=1; }
    if (( dirty )); then
      FRAME=(); add_crumbs options
      add_title "Login screen (SDDM)" "${current_dm:+active: ${current_dm}}"
      for (( i = 0; i < n; i++ )); do
        local bg=$B_CARD mk=" " fgl=$F_TEXT vc=$F_MUTED
        (( i == cursor )) && { bg=$B_PCONT; mk="▸"; fgl=$F_ONPCONT; }
        case ${V[i]} in Enabled|Yes|Wayland) vc=$F_SUCCESS ;; Disabled|No) vc=$F_SUBTLE ;; esac
        [[ ${K[i]} == done ]] && fgl="${BOLD}${F_SUCCESS}"
        lr "${bg}${F_ACCENT}${mk} ${F_SUBTLE}$(( i + 1 ))  ${fgl}${L[i]}" "${vc}${V[i]} "
        FRAME+=("$REPLY")
      done
      FRAME+=("")
      if [[ -n $current_dm ]]; then FRAME+=("${F_SECOND}Detected display manager: ${F_TEXT}${current_dm}${RS}")
      else FRAME+=("${F_SECOND}No active display manager detected${RS}"); fi
      FRAME+=("")
      add_hints "↑↓|move" "space|toggle" "↵|select" "esc|done"
      flush_card; dirty=0
    fi
    tkey 0.5 || continue
    dirty=1
    case $KEY in
      UP|k|K)   cursor=$(( (cursor + n - 1) % n )) ;;
      DOWN|j|J) cursor=$(( (cursor + 1) % n )) ;;
      q|Q|ESC)  return 0 ;;
      ENTER|SPACE)
        case ${K[cursor]} in
          inst) OPT_SDDM=$([[ $OPT_SDDM == true ]] && echo false || echo true)
                if [[ $OPT_SDDM == true && -n $current_dm && $current_dm != sddm ]]; then REPLACE_DM=true; fi ;;
          repl) REPLACE_DM=$([[ $REPLACE_DM == true ]] && echo false || echo true) ;;
          way)  SDDM_WAYLAND=$([[ $SDDM_WAYLAND == true ]] && echo false || echo true) ;;
          done) return 0 ;;
        esac ;;
    esac
  done
}

# returns 0 start · 1 quit · 2 stay on the screen
menu_activate() {
  case ${MENU_K[$1]} in
    pkgs)  screen_packages ;;
    comp)  screen_compositors ;;
    sddm)  screen_sddm ;;
    wall)  INSTALL_FULL_WALLPAPERS=$([[ $INSTALL_FULL_WALLPAPERS == true ]] && echo false || echo true) ;;
    tele)  ENABLE_TELEMETRY=$([[ $ENABLE_TELEMETRY == true ]] && echo false || echo true) ;;
    go|redo)
      if (( ${#SELECTED_COMPOSITORS[@]} == 0 )); then UI_MSG="Choose a target compositor first"; return 2; fi
      IS_REINSTALL=false; [[ ${MENU_K[$1]} == redo ]] && IS_REINSTALL=true
      return 0 ;;
    quit)  return 1 ;;
  esac
  return 2
}

screen_menu() {   # 0 = start, 1 = quit
  local focus=0 dirty=1 n rc
  while true; do
    menu_items; n=${#MENU_L[@]}
    (( focus >= n )) && focus=$(( n - 1 ))
    (( RESIZED )) && { handle_resize; dirty=1; }
    if (( dirty )); then build_menu_frame "$focus"; flush_card; dirty=0; fi
    tkey 0.5 || continue
    UI_MSG=""; dirty=1
    case $KEY in
      UP|k|K)   focus=$(( (focus + n - 1) % n )) ;;
      DOWN|j|J) focus=$(( (focus + 1) % n )) ;;
      [1-9])    if (( KEY <= n )); then focus=$(( KEY - 1 )); menu_activate "$focus"; rc=$?; (( rc == 2 )) || return $rc; fi ;;
      ENTER|SPACE|RIGHT)
        menu_activate "$focus"; rc=$?; (( rc == 2 )) || return $rc ;;
      q|Q|ESC)  return 1 ;;
    esac
  done
}

# Opening animation: the logo wipes in left-to-right with its gradient
build_welcome_frame() {
  FRAME=(); add_header; FRAME+=("" "${F_MUTED}Starting the installer…${RS}")
}
intro_wipe() {
  handle_resize
  $SHOW_BANNER || return 0
  (( COLS < MIN_COLS || ROWS < MIN_ROWS )) && return 0
  local k
  for (( k = 2; k < BANNER_W; k += 3 )); do
    INTRO_K=$k; render_banner; build_welcome_frame; flush_card; sleep 0.02
  done
  INTRO_K=-1; render_banner
}

# =============================================================================
#  SCREEN 3 - update / install progress
#  Each step runs in a background subshell (output -> log).  Return codes:
#  0 ok · 10 done with a warning · 20 skipped · anything else = failed
# =============================================================================
RUN=(); STATE=(); NOTES=(); DUR=(); DONE_N=0; RUN_MS=0; RETRY=()

fmt_ms_() { fmt_ms "$1"; }

build_update_frame() {   # $1 permille  $2 tick  $3 running-elapsed-ms
  local pm=$1 tick=$2 el=$3 i ic right lab total=${#RUN[@]}
  FRAME=()
  add_crumbs update
  add_title "${TUI_VERB}" "${DONE_N} / ${total}"
  bar "$pm" "$IW"; FRAME+=("$REPLY" "")
  for i in "${RUN[@]}"; do
    status_icon "${STATE[i]}" "$tick"; ic=$REPLY
    case ${STATE[i]} in
      queued)  lab=$F_MUTED;   right="${F_SUBTLE}queued" ;;
      running) lab=$F_TEXT;    fmt_ms "$el"; right="${F_ACCENT}running  ${F_SUBTLE}${REPLY}" ;;
      ok)      lab=$F_TEXT;    right="${F_SUCCESS}done  ${F_SUBTLE}${DUR[i]}" ;;
      warn)    lab=$F_TEXT;    right="${F_WARN}done with warning" ;;
      skip)    lab=$F_MUTED;   right="${F_MUTED}skipped" ;;
      fail)    lab=$F_TEXT;    right="${F_ERROR}failed" ;;
    esac
    lr "${ic} ${lab}${STEP_LABEL[i]}${RS}" "${right}${RS}"; FRAME+=("$REPLY")
  done
  FRAME+=("")
  add_log_box
  FRAME+=("")
  trunc "log  ${LOGFILE/#$HOME_DIR/\~}" "$IW"; FRAME+=("${F_SUBTLE}${REPLY}${RS}")
}

tui_load_state() { mapfile -t FAILED_PKGS < "$STATE_FILE" 2>/dev/null || FAILED_PKGS=(); }
tui_save_state() { printf '%s\n' "${FAILED_PKGS[@]}" 2>/dev/null | grep -v '^$' > "$STATE_FILE" 2>/dev/null || true; }

run_all_ui() {
  local i total=${#RUN[@]} pid rc tick=0 t0 t1 el pm tw=0 dw wi
  for i in "${RUN[@]}"; do STATE[i]=queued; NOTES[i]=""; DUR[i]=""; tw=$(( tw + STEP_WEIGHT[i] )); done
  DONE_N=0; dw=0; LOG_TAIL=(); local run_t0=${EPOCHREALTIME/./}
  drain_keys
  for i in "${RUN[@]}"; do
    STATE[i]=running
    : > "$NOTE_FILE"
    printf '\n══ %s ══\n' "${STEP_LABEL[i]}" >> "$LOGFILE"
    ( set -e; trap tui_save_state EXIT; tui_load_state; "step_${STEP_IDS[i]}" ) >> "$LOGFILE" 2>&1 < /dev/null &
    pid=$!; CUR_PID=$pid; t0=${EPOCHREALTIME/./}; el=0; wi=${STEP_WEIGHT[i]}
    while kill -0 "$pid" 2>/dev/null || (( el < 350 )); do
      handle_resize
      t1=${EPOCHREALTIME/./}; el=$(( (t1 - t0) / 1000 ))
      (( tick % 5 == 0 )) && refresh_log_tail
      pm=$(( (dw * 1000 + wi * el * 900 / (el + 4000)) / tw ))
      build_update_frame "$pm" "$tick" "$el"; flush_card
      tick=$(( tick + 1 )); sleep 0.09
    done
    wait "$pid"; rc=$?; CUR_PID=""
    t1=${EPOCHREALTIME/./}; fmt_ms $(( (t1 - t0) / 1000 )); DUR[i]=$REPLY
    NOTES[i]=$(head -n1 "$NOTE_FILE" 2>/dev/null)
    case $rc in
      0)  STATE[i]=ok ;;
      10) STATE[i]=warn ;;
      20) STATE[i]=skip ;;
      *)  STATE[i]=fail; [[ -z ${NOTES[i]} ]] && NOTES[i]="exited with code ${rc}" ;;
    esac
    DONE_N=$(( DONE_N + 1 )); dw=$(( dw + wi ))
  done
  tui_load_state
  RUN_MS=$(( RUN_MS + (${EPOCHREALTIME/./} - run_t0) / 1000 ))
  refresh_log_tail; tick=$(( tick + 1 ))
  build_update_frame 1000 "$tick" 0; flush_card
  sleep 0.5
}

# =============================================================================
#  SCREEN 4 - results
# =============================================================================
count_state() { local i n=0; for i in "${RUN[@]}"; do [[ ${STATE[i]} == "$1" ]] && n=$(( n + 1 )); done; REPLY=$n; }
did() { [[ ${STATE[$1]:-} == ok || ${STATE[$1]:-} == warn ]]; }

step_index() { local i; for (( i = 0; i < ${#STEP_IDS[@]}; i++ )); do [[ ${STEP_IDS[i]} == "$1" ]] && { REPLY=$i; return 0; }; done; REPLY=-1; return 1; }

short_tips() {   # -> TIPS[]
  TIPS=()
  step_index sddm; [[ $OPT_SDDM == true ]] && did "$REPLY" && TIPS+=("Log out or reboot to see the new SDDM login screen")
  TIPS+=("Reboot or log out to start the Serpantinum session")
  TIPS+=("SUPER+H opens Settings  ·  SUPER+G toggles Infinite Desktop")
  (( ${#FAILED_PKGS[@]} > 0 )) && TIPS+=("Retry the missing packages with your package manager")
}

retry_set() {
  local i; RETRY=()
  for i in "${RUN[@]}"; do [[ ${STATE[i]} == fail ]] && RETRY+=("$i"); done
  (( ${#RETRY[@]} > 0 ))
}

build_done_frame() {
  local i n_ok n_warn n_fail n_skip detail s t headline summary hg
  count_state ok; n_ok=$REPLY; count_state warn; n_warn=$REPLY
  count_state fail; n_fail=$REPLY; count_state skip; n_skip=$REPLY
  if (( n_fail > 0 )); then headline="Finished with issues"
  elif (( n_warn > 0 || n_skip > 0 )); then headline="Done, with notes"
  else headline="All set"; fi
  fmt_ms "$RUN_MS"; summary="${n_ok} ok"; (( n_warn )) && summary+="  ·  ${n_warn} warning"; (( n_skip )) && summary+="  ·  ${n_skip} skipped"; (( n_fail )) && summary+="  ·  ${n_fail} failed"; summary+="  ·  ${REPLY}"
  hg=${F_SUCCESS}${ICON_OK}
  (( n_warn > 0 || n_skip > 0 )) && hg=${F_WARN}${ICON_WARN}
  (( n_fail > 0 )) && hg=${F_ERROR}${ICON_FAIL}
  FRAME=(); add_crumbs done
  add_title "$headline" "$summary" "${hg} "
  FRAME+=("" "${F_MUTED}Serpantinum ${TARGET_VERSION}${TARGET_COMMIT:+ · ${TARGET_COMMIT}}${RS}" "")
  for i in "${RUN[@]}"; do
    status_icon "${STATE[i]}" 0; s=$REPLY
    case ${STATE[i]} in
      ok)   detail="${STEP_DEST[i]}"; [[ -n ${NOTES[i]} ]] && detail+=" · ${NOTES[i]}"; t=$F_MUTED
            if (( ${#detail} > IW - 21 )); then
              if [[ -n ${NOTES[i]} ]] && (( ${#NOTES[i]} <= IW - 21 )); then detail="${NOTES[i]}"; else detail="${STEP_DEST[i]}"; fi
            fi ;;
      warn) detail=${NOTES[i]:-"completed with a warning"}; t=$F_WARN ;;
      skip) detail=${NOTES[i]:-"skipped"}; t=$F_MUTED ;;
      fail) detail="${NOTES[i]} · see log"; t=$F_ERROR ;;
    esac
    padr "${STEP_LABEL[i]}" 19
    local lbl=$REPLY dw=$(( IW - 2 - 19 ))
    trunc "$detail" "$dw"
    FRAME+=("${s} ${F_TEXT}${lbl}${t}${REPLY}${RS}")
  done
  FRAME+=("" "${F_MUTED}Next${RS}")
  short_tips
  for t in "${TIPS[@]}"; do trunc "$t" $(( IW - 2 )); FRAME+=("${F_SECOND}•${F_TEXT} ${REPLY}${RS}"); done
  FRAME+=("")
  trunc "log  ${LOGFILE/#$HOME_DIR/\~}" "$IW"; FRAME+=("${F_SUBTLE}${REPLY}${RS}" "")
  if retry_set; then add_hints "r|retry failed" "b|reboot" "↵|exit"; else add_hints "b|reboot now" "↵|exit"; fi
}

screen_done() {   # 0 = exit, 3 = retry, 4 = reboot
  drain_keys
  local dirty=1
  while true; do
    (( RESIZED )) && { handle_resize; dirty=1; }
    if (( dirty )); then build_done_frame; flush_card; dirty=0; fi
    tkey 0.3 || continue
    case $KEY in
      ENTER|q|Q|ESC|SPACE) return 0 ;;
      b|B) return 4 ;;
      r|R) retry_set && return 3 ;;
    esac
  done
}

# Plain summary printed to the normal scrollback after the TUI closes
print_summary() {
  local i s t detail NC=$'\e[0m'
  echo
  printf '  %s%s%s%s  ·  Serpantinum Infinite Desktop  ·  %s report\n\n' "${BOLD}" "${F_ACCENT}" "${BANNER_TITLE}" "${NC}" "${TUI_NOUN}"
  for i in "${RUN[@]}"; do
    case ${STATE[i]} in
      ok)   s="${F_SUCCESS}${ICON_OK}"; detail="${STEP_DEST[i]}"; [[ -n ${NOTES[i]} ]] && detail+=" · ${NOTES[i]}"; t=$F_MUTED ;;
      warn) s="${F_WARN}${ICON_WARN}";  detail=${NOTES[i]:-"completed with a warning"}; t=$F_WARN ;;
      skip) s="${F_MUTED}${ICON_SKIP}"; detail=${NOTES[i]:-skipped}; t=$F_MUTED ;;
      fail) s="${F_ERROR}${ICON_FAIL}"; detail="${NOTES[i]} - see log"; t=$F_ERROR ;;
    esac
    printf '  %s%s %s%-20s%s%s%s\n' "$s" "$NC" "${F_TEXT}" "${STEP_LABEL[i]}" "$t" "$detail" "$NC"
  done
  if (( ${#FAILED_PKGS[@]} > 0 )); then
    printf '\n  %sNot installed:%s %s\n' "${F_WARN}" "$NC" "${FAILED_PKGS[*]}"
  fi
  printf '\n  %slog  %s%s\n\n' "${F_SUBTLE}" "$LOGFILE" "$NC"
}

# =============================================================================
#  Lifecycle
# =============================================================================
tui_enabled() {
  [[ ${SERPANTINUM_PLAIN:-} != 1 && -t 0 && -t 1 && ${TERM:-dumb} != dumb && -z ${NO_COLOR:-} ]]
}

tui_cleanup() {
  [[ -n ${CUR_PID:-} ]] && kill "$CUR_PID" 2>/dev/null
  [[ -n ${KEEPALIVE_PID:-} ]] && kill "$KEEPALIVE_PID" 2>/dev/null
  if $UI_ACTIVE; then
    UI_ACTIVE=false
    printf '\e[?2026l\e[0m\e[?25h\e[?1049l'
    [[ -n $STTY_SAVED ]] && stty "$STTY_SAVED" 2>/dev/null
  fi
  [[ -n ${NOTE_FILE:-} ]] && rm -f "$NOTE_FILE"
  [[ -n ${STATE_FILE:-} ]] && rm -f "$STATE_FILE"
  [[ -n ${WP_PREFETCH_FILE:-} ]] && rm -f "$WP_PREFETCH_FILE"
}

ui_start() {
  STTY_SAVED=$(stty -g 2>/dev/null) || STTY_SAVED=""
  stty -echo 2>/dev/null
  printf '\e[?1049h\e[?25l\e]0;%s · installer\a' "Serpantinum"
  UI_ACTIVE=true
  RESIZED=1
}

ui_stop() {
  UI_ACTIVE=false
  printf '\e[?2026l\e[0m\e[?25h\e[?1049l'
  [[ -n $STTY_SAVED ]] && stty "$STTY_SAVED" 2>/dev/null
}

# Phase 1: logs, palette, screen, administrator password.
# Exits the installer when access is cancelled or refused.
tui_begin() {
  tui_init_logs
  init_palette
  tui_specs_init
  trap tui_cleanup EXIT
  trap 'exit 130' INT TERM
  trap 'RESIZED=1' WINCH
  ui_start
  intro_wipe
  tui_access; local rc=$?
  if (( rc != 0 )); then
    ui_stop
    if (( rc == 1 )); then echo "Cancelled."; else echo "Administrator access is required to install Serpantinum."; fi
    exit 1
  fi
}

# Phase 3-4: options done -> update screen -> result screen.
tui_finish_flow() {
  local rc all_run
  tui_set_verb
  build_run_list
  declare -f wallpapers_prefetch_start >/dev/null && wallpapers_prefetch_start
  run_all_ui
  while true; do
    screen_done; rc=$?
    (( rc == 3 )) || break
    all_run=("${RUN[@]}"); RUN=("${RETRY[@]}")
    tui_access >/dev/null || true
    run_all_ui
    RUN=("${all_run[@]}")
  done
  ui_stop
  print_summary
  if (( rc == 4 )); then sudo reboot now; fi
}

build_run_list() { local i; RUN=(); for (( i = 0; i < ${#STEP_IDS[@]}; i++ )); do RUN+=("$i"); done; }
