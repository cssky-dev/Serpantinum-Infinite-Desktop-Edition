#!/usr/bin/env bash

THEME_NAME="Serpantinum"
BANNER_TITLE="SERPANTINUM"

SERPANTINUM_WEBSITE="${SERPANTINUM_WEBSITE:-https://github.com/cssky-dev}"
SB_SITE="${SERPANTINUM_WEBSITE#*://}"; SB_SITE="${SB_SITE%/}"
ORIG_DEV="@ilyamiro"
ORIG_SITE="github.com/ilyamiro/serpantinum"

GRADIENT_STOPS=(
  "72 132 255"
  "98 190 255"
  "142 232 255"
  "226 247 255"
)

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

tui_note() { printf '%s\n' "$*" > "$NOTE_FILE"; }

TRUECOLOR=false
case "${COLORTERM:-}" in *truecolor*|*24bit*) TRUECOLOR=true ;; esac
case "${TERM:-}" in *-direct|*kitty*|*alacritty*|*wezterm*|foot*) TRUECOLOR=true ;; esac

P_BG="8 12 24"
P_LOW="11 17 32"
P_CARD="16 24 44"
P_HIGH="28 40 72"
P_OUTLINE="46 62 112"
P_ACCENT="122 166 255"
P_PRIMARY="170 198 255"
P_PCONT="32 56 120"
P_ONPCONT="218 229 255"
P_TEXT="228 234 250"
P_MUTED="141 154 192"
P_SUBTLE="86 100 146"
P_SECOND="124 214 245"
P_TERTIARY="208 192 255"
P_TCONT="64 50 116"
P_SUCCESS="124 227 195"
P_WARN="255 213 138"
P_ERROR="255 143 166"
P_ECONT="72 24 44"
P_SCONT="20 66 56"
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
  RL=$'\e[0m'"${B_LOW}${F_TEXT}"               # reset -> sidebar surface
  ICON_OK="✓"; ICON_FAIL="✗"; ICON_WARN="!"; ICON_SKIP="–"; ICON_QUEUE="○"
}

init_palette_plain() {
  local t
  for t in "${PALETTE_TOKENS[@]}"; do printf -v "F_$t" '%s' ''; printf -v "B_$t" '%s' ''; done
  BOLD=''; R0=''; RS=''; RL=''
  ICON_OK="[ok]"; ICON_FAIL="[x]"; ICON_WARN="[!]"; ICON_SKIP="[-]"; ICON_QUEUE="[ ]"
}

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

strip_sgr() {   # drop colour escapes from untrusted text (log lines)
  local s=$1 out=''
  while [[ $s == *$'\e'* ]]; do out+=${s%%$'\e'*}; s=${s#*$'\e'}; s=${s#*[A-Za-z]}; done
  REPLY=${out}${s}
}
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

UI_ACTIVE=false; RESIZED=1; ROWS=24; COLS=80; PAD=3; LAST_GEOM=""
SIDEBAR_WANTED=false; SB_ON=false; SB_W=0; SB_CUR=update; SB_PM=""; SB_N=""; SB_KEY=""
SBL=(); SBF=(); LOGO_OK=false; CRUMB_RUN=install; CRUMB_BUSY=update
MIN_COLS=56; MIN_ROWS=18
FRAME=(); OUT=""; CARD_TOP=1
STTY_SAVED=""

get_size() {
  local sz; sz=$(stty size 2>/dev/null) || sz=""
  if [[ $sz =~ ^([0-9]+)\ ([0-9]+)$ ]]; then ROWS=${BASH_REMATCH[1]}; COLS=${BASH_REMATCH[2]}
  else ROWS=${LINES:-24}; COLS=${COLUMNS:-80}; fi
}

layout() {
  SB_ON=false; SB_W=0; PAD=3
  if $SIDEBAR_WANTED && (( COLS >= 98 && ROWS >= 27 )); then
    SB_ON=true; PAD=2; SB_W=22; (( COLS >= 124 )) && SB_W=26
  fi
  if $SB_ON; then
    W=$(( COLS - 4 )); (( W > 122 )) && W=122
    IW=$(( W - 3 - SB_W - 2 * PAD ))
  else
    W=$(( COLS - 4 )); (( W > 88 )) && W=88
    IW=$(( W - 2 - 2 * PAD ))
  fi
  CX=$(( (COLS - W) / 2 + 1 ))
  printf -v PADSTR '%*s' "$PAD" ''
}

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
  SHOW_BANNER=false; SHOW_INFO=false; SHOW_CRUMBS=false; LOGO_OK=false
  (( IW >= BANNER_W + 2 )) && LOGO_OK=true
  if ! $SB_ON; then
    (( ROWS >= 34 && IW >= 44 )) && SHOW_CRUMBS=true
    (( ROWS >= 25 + ${#BANNER[@]} && IW >= BANNER_W + 2 )) && SHOW_BANNER=true
    $SHOW_BANNER && (( ROWS >= 27 + ${#BANNER[@]} )) && SHOW_INFO=true
  fi

  SB_KEY=""
  if $SB_ON; then
    if (( SB_W >= 26 )); then track "SERPANTINUM"; else REPLY="SERPANTINUM"; fi
    gradient_str "$REPLY"; SB_TITLE="${BOLD}${REPLY}${RL}"
    rep '─' $(( SB_W - 2 )); gradient_str "$REPLY"; SB_DIV="${REPLY}${RL}"
  fi

  INTRO_K=-1; render_banner
  track "${BANNER_TITLE^^}"; gradient_str "$REPLY"; center "${BOLD}${REPLY}${RS}"; TITLE_R=$REPLY
  local sub; track "INFINITE DESKTOP INSTALLER"; sub=$REPLY
  if (( ${#sub} + 11 <= IW )); then
    gradient_str "$sub" 0 $(( ${#sub} + 10 )); SUB_G=$REPLY
    center "${SUB_G}${RS}${F_SUBTLE}   ·   ${F_MUTED}CSSKY${RS}"
  else
    sub="Infinite Desktop installer"; gradient_str "$sub"; center "${REPLY}${RS}"
  fi
  SUB_R=$REPLY
}

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

put_line() {   # put_line ROW CONTENT [SIDEBAR-CELL]
  (( $1 > ROWS )) && return
  local v sp pad sb='' sv sbp
  vlen "$2"; v=$REPLY; pad=$(( IW - v )); (( pad < 0 )) && pad=0
  printf -v sp '%*s' "$pad" ''
  if $SB_ON; then
    vlen "${3:-}"; sv=$REPLY
    printf -v sbp '%*s' $(( SB_W - sv > 0 ? SB_W - sv : 0 )) ''
    sb="${B_LOW}${F_TEXT}${3:-}${RL}${sbp}${B_CARD}${F_OUTLINE}│"
  fi
  OUT+=$'\e['"$1;${CX}H${B_CARD}${F_OUTLINE}│${sb}${RS}${PADSTR}${2}${RS}${sp}${PADSTR}${F_OUTLINE}│${R0}"
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
  local n=${#FRAME[@]} T h top row i geom sbn=0 fn=0 cell content
  if $SB_ON; then build_sidebar; sbn=${#SBL[@]}; fn=${#SBF[@]}; fi
  T=$(( n + 2 )); (( sbn + fn > T )) && T=$(( sbn + fn ))
  h=$(( T + 2 )); top=$(( (ROWS - h) / 2 + 1 )); (( top < 1 )) && top=1
  CARD_TOP=$top
  OUT=$'\e[?2026h'
  geom="${ROWS}x${COLS}/${top}/${h}/${SB_ON}"
  if [[ $geom != "$LAST_GEOM" ]]; then paint_bg; LAST_GEOM=$geom; fi
  row=$top
  OUT+=$'\e['"${row};${CX}H${TOPB}"; row=$(( row + 1 ))
  for (( i = 0; i < T; i++ )); do
    cell=''; content=''
    if $SB_ON; then
      if (( i < sbn )); then cell=${SBL[i]}
      elif (( i >= T - fn )); then cell=${SBF[i - (T - fn)]}; fi
    fi
    (( i >= 1 && i <= n )) && content=${FRAME[i - 1]}
    put_line "$row" "$content" "$cell"; row=$(( row + 1 ))
  done
  (( row <= ROWS )) && OUT+=$'\e['"${row};${CX}H${BOTB}"
  printf '%s' "${OUT}${R0}"$'\e[?2026l'
}

SB_IDS=(update welcome deps options install done)
SB_LAB=("System update" "Welcome" "Dependencies" "Options" "Setup" "Finish")

build_sidebar() {
  local key="${SB_CUR}|${SB_PM}|${SB_N}|${SB_W}"
  [[ $key == "$SB_KEY" ]] && return 0
  SB_KEY=$key
  local i cur=-1 lab ic col line cw=$(( SB_W - 2 ))
  for (( i = 0; i < ${#SB_IDS[@]}; i++ )); do [[ ${SB_IDS[i]} == "$SB_CUR" ]] && cur=$i; done
  SBL=("" " ${SB_TITLE}" " ${F_MUTED}Infinite Desktop${RL}" " ${F_SUBTLE}v${TARGET_VERSION:-?}${RL}" " ${SB_DIV}" "")
  for (( i = 0; i < ${#SB_IDS[@]}; i++ )); do
    lab=${SB_LAB[i]}
    if (( i < cur )); then ic="${F_SUCCESS}${ICON_OK}"; col=$F_MUTED
    elif (( i == cur )); then ic="${F_ACCENT}●"; col="${BOLD}${F_ONPCONT}"
    else ic="${F_SUBTLE}○"; col=$F_SUBTLE; fi
    if (( i == cur )); then
      pad_to "${B_PCONT} ${ic} ${col}${lab}" "$cw"; SBL+=(" ${REPLY}${RL}")
    else
      SBL+=("  ${ic} ${col}${lab}${RL}")
    fi
    if (( i < ${#SB_IDS[@]} - 1 )); then
      if (( i < cur )); then SBL+=("  ${F_SUCCESS}│${RL}"); else SBL+=("  ${F_OUTLINE}│${RL}"); fi
    fi
  done
  if [[ -n $SB_PM && $SB_CUR == install ]]; then
    bar "$SB_PM" $(( SB_W - 4 ))
    SBL+=("" " ${REPLY}${RL}" " ${F_MUTED}${SB_N}${RL}")
  fi
  trunc "$SB_SITE" $(( SB_W - 2 ))
  SBF=("" " ${F_SUBTLE}website${RL}" " ${F_SECOND}${REPLY}${RL}" " ${F_SUBTLE}press ${F_PRIMARY}w${F_SUBTLE} to open${RL}")
}

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

TUI_NOUN="Update"; TUI_VERB="Updating"

tui_set_verb() {
  if [[ ${IS_REINSTALL:-false} == true ]]; then TUI_NOUN="Reinstall"; TUI_VERB="Reinstalling"
  elif [[ ${INSTALL_STATE:-fresh} == current ]]; then TUI_NOUN="Update"; TUI_VERB="Updating"
  else TUI_NOUN="Install"; TUI_VERB="Installing"; fi
}

add_crumbs() {   # add_crumbs update|welcome|deps|options|install|done   (card layout only)
  $SHOW_CRUMBS || return 0
  local cur=$1 id lab line='' plain=0 pos=past
  for id in update welcome deps options install done; do
    case $id in update) lab=System ;; welcome) lab=Welcome ;; deps) lab=Dependencies ;; options) lab=Options ;; install) lab=Setup ;; done) lab=Done ;; esac
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
  add_crumbs update
  add_title "Administrator password" "" "${F_TERTIARY}◆ "
  FRAME+=("" "${F_TEXT}Needed to update your system first:${RS}")
  FRAME+=("${F_SECOND}•${F_TEXT} refresh the package databases and upgrade the system${RS}")
  FRAME+=("${F_SECOND}•${F_TEXT} prepare the tools the installer relies on${RS}")
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
              else status="${F_MUTED}Enter your password to start the update."; fi ;;
  esac
  FRAME+=("" "${status}${RS}" "")
  add_hints "↵|update" "esc|cancel" "ctrl-c|quit"
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

build_busy_frame() {   # $1 title  $2 note  $3 tick
  FRAME=()
  add_crumbs "$CRUMB_BUSY"
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

MENU_L=(); MENU_V=(); MENU_K=(); MENU_H=(); UI_MSG=""

tui_pause()  { printf '\e[?25h'; stty echo 2>/dev/null; printf '\e[0m\e[2J\e[H'; }
tui_resume() { printf '\e[?25l'; stty -echo 2>/dev/null; RESIZED=1; LAST_GEOM=''; }

menu_items() {
  local c v
  MENU_L=(); MENU_V=(); MENU_K=(); MENU_H=()
  MENU_L+=("Dependencies"); MENU_V+=("${#REQUIRED_PKGS[@]} packages + font"); MENU_K+=(pkgs)
  MENU_H+=("Check packages, JetBrainsMono Nerd Font, qt5ct and qt6ct")
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
  if ! $SB_ON; then add_header; FRAME+=(""); fi
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

PK_NAME=(); PK_MISS=(); PK_NOTE=()
DEP_PINNED=(ttf-jetbrains-mono-nerd qt5ct qt6ct)
screen_deps() {
  local flow=${1:-0} target=() missing_raw p c pin
  CRUMB_BUSY=deps; tui_status "Dependencies" "Checking what is installed…"; CRUMB_BUSY=update
  target=("${REQUIRED_PKGS[@]}")
  for c in "${SELECTED_COMPOSITORS[@]}"; do target+=("$(compositor_package_name "$c")"); done
  if [[ $OPT_SDDM == true ]]; then
    local sddm_pkgs=(); mapfile -t sddm_pkgs < <(sddm_packages); target+=("${sddm_pkgs[@]}")
  fi
  target+=("${PM_EXTRA_PKGS[@]}")
  missing_raw=$(pm_missing_pkgs "${target[@]}" 2>/dev/null)
  local -A miss=() note=()
  while IFS= read -r p; do [[ -n $p ]] && miss["$p"]=1; done <<< "$missing_raw"
  note[ttf-jetbrains-mono-nerd]="JetBrainsMono Nerd Font"
  note[qt5ct]="Qt5 app theming"
  note[qt6ct]="Qt6 app theming"
  PK_NAME=(); PK_MISS=(); PK_NOTE=()
  for pin in "${DEP_PINNED[@]}"; do
    PK_NAME+=("$pin"); PK_NOTE+=("${note[$pin]}")
    if [[ $pin == ttf-jetbrains-mono-nerd ]]; then
      font_jetbrains_nerd_installed && PK_MISS+=(0) || PK_MISS+=(1)
    else
      [[ -n ${miss[$pin]:-} ]] && PK_MISS+=(1) || PK_MISS+=(0)
    fi
  done
  for p in "${target[@]}"; do
    [[ " ${DEP_PINNED[*]} " == *" $p "* ]] && continue
    PK_NAME+=("$p"); PK_NOTE+=("")
    [[ -n ${miss[$p]:-} ]] && PK_MISS+=(1) || PK_MISS+=(0)
  done

  local n=${#PK_NAME[@]} nm=0 i top=0 win dirty=1 rows ready npin=${#DEP_PINNED[@]}
  for (( i = 0; i < n; i++ )); do (( PK_MISS[i] )) && nm=$(( nm + 1 )); done
  ready=$(( n - nm ))
  local -a DR=("H|Shell font and Qt theming")
  for (( i = 0; i < npin; i++ )); do DR+=("P|$i"); done
  DR+=("H|Packages")
  for (( i = npin; i < n; i++ )); do DR+=("P|$i"); done
  local dn=${#DR[@]}
  drain_keys
  while true; do
    (( RESIZED )) && { handle_resize; dirty=1; }
    rows=$(( ROWS - 16 )); (( rows > 20 )) && rows=20; (( rows < 4 )) && rows=4; win=$rows; (( win > dn )) && win=$dn
    (( top > dn - win )) && top=$(( dn - win )); (( top < 0 )) && top=0
    if (( dirty )); then
      FRAME=(); add_crumbs deps
      add_title "Dependencies" "${nm} to install  ·  ${n} total"
      lr "${F_MUTED}${ready} of ${n} ready${RS}" "$( (( nm )) && printf '%s' "${F_ACCENT}${nm} will be installed" || printf '%s' "${F_SUCCESS}everything is installed" )"
      FRAME+=("$REPLY"); bar $(( ready * 1000 / n )) "$IW"; FRAME+=("$REPLY" "")
      for (( i = top; i < top + win; i++ )); do
        local kind=${DR[i]%%|*} val=${DR[i]#*|} ic lab st stc nt
        if [[ $kind == H ]]; then
          FRAME+=("${F_SUBTLE}── ${F_MUTED}${BOLD}${val}${RS}")
        else
          if (( PK_MISS[val] )); then ic="${F_ACCENT}+"; lab="${F_TEXT}"; st="will be installed"; stc=$F_ACCENT
          else ic="${F_SUCCESS}${ICON_OK}"; lab="${F_MUTED}"; st="installed"; stc=$F_SUBTLE; fi
          padr "${PK_NAME[val]}" 26; nt=""
          (( IW >= 66 )) && [[ -n ${PK_NOTE[val]} ]] && nt="${F_SUBTLE}${PK_NOTE[val]}"
          lr "  ${ic} ${lab}${REPLY}${nt}" "${stc}${st} "
          FRAME+=("$REPLY")
        fi
      done
      FRAME+=("" "${F_SUBTLE}$(( top + 1 ))-$(( top + win )) of ${dn}${RS}")
      if (( ${#SELECTED_COMPOSITORS[@]} == 0 && flow )); then
        FRAME+=("${F_SECOND}Compositor and login-screen packages are added once you pick them in Options${RS}")
      else FRAME+=(""); fi
      FRAME+=("")
      if (( flow )); then add_hints "↑↓|scroll" "↵|continue" "←|back" "w|website" "q|quit"
      else add_hints "↑↓|scroll" "↵|back"; fi
      flush_card; dirty=0
    fi
    tkey 0.5 || continue
    dirty=1
    case $KEY in
      UP|k|K)   (( top > 0 )) && top=$(( top - 1 )) ;;
      DOWN|j|J) (( top < dn - win )) && top=$(( top + 1 )) ;;
      w|W)      tui_open_site ;;
      ENTER|RIGHT) return 0 ;;
      LEFT|b|B) (( flow )) && return 5; return 0 ;;
      q|Q|ESC)  (( flow )) && return 1; return 0 ;;
      SPACE)    (( flow )) || return 0 ;;
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

menu_activate() {
  case ${MENU_K[$1]} in
    pkgs)  screen_deps 0 ;;
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
      LEFT|b|B) return 5 ;;
      w|W)      tui_open_site ;;
      q|Q|ESC)  return 1 ;;
    esac
  done
}

WELCOME_SEEN=false

build_welcome_frame() {
  FRAME=()
  local l ver info=true
  (( INTRO_K >= 0 )) && info=false
  if $LOGO_OK; then
    for l in "${BANNER_R[@]}"; do FRAME+=("$l"); done
    FRAME+=("")
  else
    FRAME+=("$TITLE_R")
  fi
  FRAME+=("$SUB_R" "")
  if $info; then
    center "${BOLD}${F_TEXT}Hello!${RS}"; FRAME+=("$REPLY")
    center "${F_MUTED}Your favourite desktop, customised for YOU${RS}"; FRAME+=("$REPLY" "")
    if [[ ${INSTALL_STATE:-fresh} == current ]]; then
      ver="${F_MUTED}installed ${F_TEXT}${OLD_VERSION:-?}${F_SUBTLE}  →  ${F_SUCCESS}${TARGET_VERSION}"
    else
      ver="${F_MUTED}version ${F_SUCCESS}${TARGET_VERSION}"
    fi
    center "${ver}${RS}"; FRAME+=("$REPLY" "")
    local i lab
    for i in 0 2 3; do
      padr "${SPEC_L[i]}" 8; lab=$REPLY
      trunc "${SPEC_V[i]}" $(( IW - 14 ))
      center "${F_SUBTLE}${lab}${F_MUTED}${REPLY}${RS}"; FRAME+=("$REPLY")
    done
    FRAME+=("")
    center "${F_SUBTLE}website  ${F_SECOND}${SB_SITE}${RS}"; FRAME+=("$REPLY")
    center "${F_SUBTLE}original dev  ${F_SECOND}${ORIG_DEV}${F_SUBTLE}  ·  ${F_SECOND}${ORIG_SITE}${RS}"; FRAME+=("$REPLY" "")
    add_hints "↵|start" "w|website" "q|quit"
  else
    FRAME+=("" "" "" "" "" "" "" "" "" "" "" "")
  fi
}

screen_welcome() {   # 0 continue · 1 quit
  local dirty=1 k
  SB_CUR=welcome; tui_set_verb
  printf '\e]0;%s · installer\a' "Serpantinum"
  handle_resize
  if ! $WELCOME_SEEN; then
    WELCOME_SEEN=true
    if $LOGO_OK && (( COLS >= MIN_COLS && ROWS >= MIN_ROWS )); then
      for (( k = 2; k < BANNER_W; k += 3 )); do
        INTRO_K=$k; render_banner; build_welcome_frame; flush_card; sleep 0.02
      done
    fi
    INTRO_K=-1; render_banner
  fi
  drain_keys
  while true; do
    (( RESIZED )) && { handle_resize; dirty=1; }
    if (( dirty )); then build_welcome_frame; flush_card; dirty=0; fi
    tkey 0.5 || continue
    case $KEY in
      ENTER|SPACE|RIGHT) return 0 ;;
      w|W) tui_open_site ;;
      q|Q|ESC) return 1 ;;
    esac
  done
}

tui_open_site() {
  command -v xdg-open &>/dev/null || return 0
  ( setsid xdg-open "$SERPANTINUM_WEBSITE" >/dev/null 2>&1 & ) 2>/dev/null
}

RUN=(); STATE=(); NOTES=(); DUR=(); DONE_N=0; RUN_MS=0; RETRY=()

fmt_ms_() { fmt_ms "$1"; }

build_update_frame() {   # $1 permille  $2 tick  $3 running-elapsed-ms
  local pm=$1 tick=$2 el=$3 i ic right lab total=${#RUN[@]} room
  FRAME=()
  add_crumbs "$CRUMB_RUN"
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
  room=$(( ROWS - 4 - ${#FRAME[@]} ))
  if (( room >= 7 )); then
    add_log_box
    FRAME+=("")
    trunc "log  ${LOGFILE/#$HOME_DIR/\~}" "$IW"; FRAME+=("${F_SUBTLE}${REPLY}${RS}")
  elif (( room >= 1 )); then
    trunc "log  ${LOGFILE/#$HOME_DIR/\~}" "$IW"; FRAME+=("${F_SUBTLE}${REPLY}${RS}")
  fi
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
      SB_PM=$pm; SB_N="${DONE_N} / ${total}"
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
  SB_PM=1000; SB_N="${DONE_N} / ${total}"
  build_update_frame 1000 "$tick" 0; flush_card
  sleep 0.5
}

count_state() { local i n=0; for i in "${RUN[@]}"; do [[ ${STATE[i]} == "$1" ]] && n=$(( n + 1 )); done; REPLY=$n; }
did() { [[ ${STATE[$1]:-} == ok || ${STATE[$1]:-} == warn ]]; }

step_index() { local i; for (( i = 0; i < ${#STEP_IDS[@]}; i++ )); do [[ ${STEP_IDS[i]} == "$1" ]] && { REPLY=$i; return 0; }; done; REPLY=-1; return 1; }

short_tips() {   # -> TIPS[]
  TIPS=()
  step_index sddm; [[ $OPT_SDDM == true ]] && did "$REPLY" && TIPS+=("Log out or reboot to see the new SDDM login screen")
  TIPS+=("Reboot or log out to start the Serpantinum session")
  TIPS+=("Qt apps use qt6ct (QT_QPA_PLATFORMTHEME), qt5ct is ready too")
  TIPS+=("SUPER+H opens Settings  ·  SUPER+G toggles Infinite Desktop")
  (( ${#FAILED_PKGS[@]} > 0 )) && TIPS+=("Retry the missing packages with your package manager")
}

retry_set() {
  local i; RETRY=()
  for i in "${RUN[@]}"; do [[ ${STATE[i]} == fail ]] && RETRY+=("$i"); done
  (( ${#RETRY[@]} > 0 ))
}

build_done_frame() {
  local i n_ok n_warn n_fail n_skip detail st t headline summary hg tight=false shown=0 tips_n
  count_state ok; n_ok=$REPLY; count_state warn; n_warn=$REPLY
  count_state fail; n_fail=$REPLY; count_state skip; n_skip=$REPLY
  if (( n_fail > 0 )); then headline="Finished with issues"
  elif (( n_warn > 0 || n_skip > 0 )); then headline="Done, with notes"
  else headline="All set"; fi
  fmt_ms "$RUN_MS"; summary="${n_ok} ok"; (( n_warn )) && summary+="  ·  ${n_warn} warning"; (( n_skip )) && summary+="  ·  ${n_skip} skipped"; (( n_fail )) && summary+="  ·  ${n_fail} failed"; summary+="  ·  ${REPLY}"
  hg=${F_SUCCESS}${ICON_OK}
  (( n_warn > 0 || n_skip > 0 )) && hg=${F_WARN}${ICON_WARN}
  (( n_fail > 0 )) && hg=${F_ERROR}${ICON_FAIL}
  short_tips; tips_n=${#TIPS[@]}
  # not enough rows for every step: collapse the ones that went fine
  (( 2 + 3 + ${#RUN[@]} + 2 + tips_n + 3 + 4 > ROWS - 2 )) && tight=true
  FRAME=(); add_crumbs done
  add_title "$headline" "$summary" "${hg} "
  FRAME+=("" "${F_MUTED}Serpantinum ${TARGET_VERSION}${TARGET_COMMIT:+ · ${TARGET_COMMIT}}${RS}" "")
  for i in "${RUN[@]}"; do
    if $tight && [[ ${STATE[i]} == ok ]]; then continue; fi
    status_icon "${STATE[i]}" 0; st=$REPLY
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
    FRAME+=("${st} ${F_TEXT}${lbl}${t}${REPLY}${RS}")
    shown=$(( shown + 1 ))
  done
  if $tight; then FRAME+=("${F_SUCCESS}${ICON_OK}${F_MUTED} ${n_ok} steps completed${RS}"); fi
  FRAME+=("" "${F_MUTED}Next${RS}")
  for t in "${TIPS[@]}"; do trunc "$t" $(( IW - 2 )); FRAME+=("${F_SECOND}•${F_TEXT} ${REPLY}${RS}"); done
  FRAME+=("")
  if ! $tight || (( ${#FRAME[@]} + 7 <= ROWS )); then
    lr "${F_SUBTLE}website  ${F_SECOND}${SB_SITE}${RS}" ""; FRAME+=("$REPLY")
    lr "${F_SUBTLE}original dev  ${F_SECOND}${ORIG_DEV}${F_SUBTLE}  ·  ${F_SECOND}${ORIG_SITE}${RS}" ""; FRAME+=("$REPLY")
  fi
  trunc "log  ${LOGFILE/#$HOME_DIR/\~}" "$IW"; FRAME+=("${F_SUBTLE}${REPLY}${RS}" "")
  if retry_set; then add_hints "r|retry failed" "b|reboot" "w|website" "↵|exit"; else add_hints "b|reboot now" "w|website" "↵|exit"; fi
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
      w|W) tui_open_site ;;
      r|R) retry_set && return 3 ;;
    esac
  done
}

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
  printf '\e[?1049h\e[?25l\e]0;%s\a' "Installer"
  UI_ACTIVE=true
  RESIZED=1
}

ui_stop() {
  UI_ACTIVE=false
  printf '\e[?2026l\e[0m\e[?25h\e[?1049l'
  [[ -n $STTY_SAVED ]] && stty "$STTY_SAVED" 2>/dev/null
}

tui_begin() {
  tui_init_logs
  init_palette
  tui_specs_init
  trap tui_cleanup EXIT
  trap 'exit 130' INT TERM
  trap 'RESIZED=1' WINCH
  ui_start
  tui_access; local rc=$?
  if (( rc != 0 )); then
    ui_stop
    if (( rc == 1 )); then echo "Cancelled."; else echo "Administrator access is required to update your system."; fi
    exit 1
  fi
}

step_sysrepos()   { bootstrap_repos; }
step_systools()   { bootstrap_tools; bootstrap_helper; }
step_sysupgrade() { pm_full_upgrade; }

sysupdate_prompt() {   # $1 = may continue anyway ·  returns 0 continue · 1 retry · 2 quit
  local can=$1 dirty=1
  drain_keys
  while true; do
    (( RESIZED )) && { handle_resize; dirty=1; }
    if (( dirty )); then
      build_update_frame 1000 0 0
      FRAME+=("")
      if (( can )); then FRAME+=("${F_WARN}${ICON_WARN} The system upgrade did not finish. You can continue anyway.${RS}")
      else FRAME+=("${F_ERROR}${ICON_FAIL} The installer tools could not be prepared. See the log.${RS}"); fi
      FRAME+=("")
      if (( can )); then add_hints "↵|continue" "r|retry" "q|quit"; else add_hints "r|retry" "q|quit"; fi
      flush_card; dirty=0
    fi
    tkey 0.4 || continue
    case $KEY in
      ENTER) (( can )) && return 0 ;;
      r|R) return 1 ;;
      q|Q|ESC) return 2 ;;
    esac
  done
}

tui_system_update() {
  local sv_ids=("${STEP_IDS[@]}") sv_lab=("${STEP_LABEL[@]}") sv_dest=("${STEP_DEST[@]}") sv_w=("${STEP_WEIGHT[@]}")
  local sv_verb=$TUI_VERB rc
  STEP_IDS=(sysrepos systools sysupgrade)
  STEP_LABEL=("Package databases" "Installer tools" "System upgrade")
  STEP_DEST=("" "" "")
  STEP_WEIGHT=(1 3 8)
  TUI_VERB="Updating your system"; CRUMB_RUN=update; SB_CUR=update
  while true; do
    RUN=(0 1 2)
    run_all_ui
    if [[ ${STATE[1]} == fail || ${STATE[0]} == fail ]]; then
      sysupdate_prompt 0; rc=$?
    elif [[ ${STATE[2]} == fail ]]; then
      sysupdate_prompt 1; rc=$?
    else
      rc=0; SYSTEM_UPGRADED=1; export SYSTEM_UPGRADED
    fi
    case $rc in
      0) break ;;
      1) continue ;;
      *) ui_stop; echo "Cancelled."; exit 1 ;;
    esac
  done
  STEP_IDS=("${sv_ids[@]}"); STEP_LABEL=("${sv_lab[@]}"); STEP_DEST=("${sv_dest[@]}"); STEP_WEIGHT=("${sv_w[@]}")
  TUI_VERB=$sv_verb; CRUMB_RUN=install; RUN=(); STATE=(); NOTES=(); DUR=(); DONE_N=0; RUN_MS=0; LOG_TAIL=()
}

tui_workflow() {
  local stage=welcome rc
  SIDEBAR_WANTED=true; RESIZED=1; handle_resize
  while true; do
    case $stage in
      welcome)
        screen_welcome; rc=$?
        (( rc == 0 )) && stage=deps || return 1 ;;
      deps)
        SB_CUR=deps; screen_deps 1; rc=$?
        case $rc in 0) stage=options ;; 5) stage=welcome ;; *) return 1 ;; esac ;;
      options)
        SB_CUR=options; screen_menu; rc=$?
        case $rc in 0) return 0 ;; 5) stage=deps ;; *) return 1 ;; esac ;;
    esac
  done
}

tui_finish_flow() {
  local rc all_run
  tui_set_verb
  build_run_list
  SB_CUR=install; CRUMB_RUN=install; SB_PM=""; RUN_MS=0
  declare -f wallpapers_prefetch_start >/dev/null && wallpapers_prefetch_start
  run_all_ui
  while true; do
    SB_CUR=done; SB_PM=""
    screen_done; rc=$?
    (( rc == 3 )) || break
    all_run=("${RUN[@]}"); RUN=("${RETRY[@]}")
    SB_CUR=install
    tui_access >/dev/null || true
    run_all_ui
    RUN=("${all_run[@]}")
  done
  ui_stop
  print_summary
  if (( rc == 4 )); then sudo reboot now; fi
}

build_run_list() { local i; RUN=(); for (( i = 0; i < ${#STEP_IDS[@]}; i++ )); do RUN+=("$i"); done; }
