#!/usr/bin/env bash

dialog_available() {
  [[ "$HAS_DIALOG" -eq 1 ]]
}

dialog_run() {
  dialog --erase-on-exit --clear "$@"
}

terminal_size() {
  local rows="" cols=""
  if [[ -t 1 ]]; then
    read -r rows cols < <(stty size 2>/dev/null || true)
  fi
  if [[ -z "$rows" || -z "$cols" ]]; then
    rows="$(tput lines 2>/dev/null || true)"
    cols="$(tput cols 2>/dev/null || true)"
  fi
  [[ "$rows" =~ ^[0-9]+$ ]] || rows=24
  [[ "$cols" =~ ^[0-9]+$ ]] || cols=80
  printf '%s %s' "$rows" "$cols"
}

dialog_percent_size() {
  local height_var="$1" width_var="$2" height_percent="$3" width_percent="$4"
  local rows cols computed_height computed_width max_height max_width
  read -r rows cols < <(terminal_size)

  max_height=$((rows - 2))
  max_width=$((cols - 4))
  ((max_height > 0)) || max_height="$rows"
  ((max_width > 0)) || max_width="$cols"

  computed_height=$((rows * height_percent / 100))
  computed_width=$((cols * width_percent / 100))
  ((computed_height >= 1)) || computed_height=1
  ((computed_width >= 1)) || computed_width=1
  ((computed_height <= max_height)) || computed_height="$max_height"
  ((computed_width <= max_width)) || computed_width="$max_width"

  printf -v "$height_var" '%s' "$computed_height"
  printf -v "$width_var" '%s' "$computed_width"
}

dialog_message_size() {
  dialog_percent_size "$1" "$2" 60 85
}

dialog_large_message_size() {
  dialog_percent_size "$1" "$2" 90 92
}

dialog_input_size() {
  dialog_percent_size "$1" "$2" 45 85
}

dialog_menu_size() {
  local height_var="$1" width_var="$2" menu_height_var="$3" item_count="$4"
  local calc_height calc_width computed_menu_height
  dialog_percent_size calc_height calc_width 85 90
  computed_menu_height=$((calc_height - 8))
  ((computed_menu_height >= 1)) || computed_menu_height=1
  ((item_count <= 0 || computed_menu_height <= item_count)) || computed_menu_height="$item_count"
  printf -v "$height_var" '%s' "$calc_height"
  printf -v "$width_var" '%s' "$calc_width"
  printf -v "$menu_height_var" '%s' "$computed_menu_height"
}

dialog_checklist_size() {
  local height_var="$1" width_var="$2" list_height_var="$3" item_count="$4"
  local calc_height calc_width computed_list_height
  dialog_percent_size calc_height calc_width 90 90
  computed_list_height=$((calc_height - 9))
  ((computed_list_height >= 1)) || computed_list_height=1
  ((item_count <= 0 || computed_list_height <= item_count)) || computed_list_height="$item_count"
  printf -v "$height_var" '%s' "$calc_height"
  printf -v "$width_var" '%s' "$calc_width"
  printf -v "$list_height_var" '%s' "$computed_list_height"
}

init_ui() {
  if need_cmd dialog && [[ -t 1 ]]; then
    HAS_DIALOG=1
  fi
}

show_error() {
  if dialog_available; then
    local height width
    dialog_message_size height width
    dialog_run --title "错误" --msgbox "$1" "$height" "$width"
  else
    printf 'Error: %s\n' "$1" >&2
  fi
}

pause_screen() {
  local message="${1:-按 Enter 继续}"
  if dialog_available; then
    local height width
    dialog_message_size height width
    dialog_run --title "$APP_TITLE" --msgbox "$message" "$height" "$width"
  else
    printf '\n%s\n' "$message"
    read -r _ || true
  fi
}

text_viewer() {
  local title="$1" text="$2"
  if dialog_available; then
    local height width text_file
    dialog_large_message_size height width
    text_file="$(mktemp "${TMPDIR:-/tmp}/installer-launcher-view.XXXXXX")" || return 1
    printf '%s\n' "$text" >"$text_file"
    dialog_run --title "$title" --textbox "$text_file" "$height" "$width" || true
    rm -f "$text_file"
  else
    printf '\n%s\n' "$text"
    read -r _ || true
  fi
}

confirm_screen() {
  local title="$1" message="$2"
  if dialog_available; then
    local height width
    dialog_large_message_size height width
    dialog_run --title "$title" --yesno "$message" "$height" "$width"
  else
    local answer
    printf '\n%s\n' "$message" >&2
    printf 'Confirm? [y/N]: ' >&2
    read -r answer || return 1
    [[ "$answer" == "y" || "$answer" == "Y" || "$answer" == "yes" || "$answer" == "YES" ]]
  fi
}

typed_confirm_screen() {
  local title="$1" message="$2" expected="$3" answer
  answer="$(input_box "$title" "${message}

请输入以下内容以继续:
${expected}" "")" || return 1
  [[ "$answer" == "$expected" ]]
}

input_box() {
  local title="$1" prompt="$2" default="${3:-}" output
  if dialog_available; then
    local height width
    dialog_input_size height width
    output=$(dialog_run --title "$title" --inputbox "$prompt" "$height" "$width" "$default" 3>&1 1>&2 2>&3) || return $?
    printf '%s' "$output"
  else
    printf '%s [%s]: ' "$prompt" "$default" >&2
    read -r output || return 1
    printf '%s' "${output:-$default}"
  fi
}

menu_select() {
  local title="$1" prompt="$2" output
  shift 2
  if dialog_available; then
    local height width menu_height item_count
    item_count=$(($# / 2))
    dialog_menu_size height width menu_height "$item_count"
    output=$(dialog_run --title "$title" --menu "$prompt" "$height" "$width" "$menu_height" "$@" 3>&1 1>&2 2>&3) || return $?
    printf '%s' "$output"
  else
    local tags=() index=1 choice
    while [[ "$#" -gt 0 ]]; do
      tags+=("$1")
      printf '%2d. %s - %s\n' "$index" "$1" "$2" >&2
      shift 2
      index=$((index + 1))
    done
    printf 'Select: ' >&2
    read -r choice || return 1
    [[ "$choice" =~ ^[0-9]+$ ]] || return 1
    (( choice >= 1 && choice <= ${#tags[@]} )) || return 1
    printf '%s' "${tags[$((choice - 1))]}"
  fi
}

checklist_select() {
  local title="$1" prompt="$2" output
  shift 2
  if dialog_available; then
    local height width list_height item_count
    item_count=$(($# / 3))
    dialog_checklist_size height width list_height "$item_count"
    output=$(dialog_run --title "$title" --checklist "$prompt" "$height" "$width" "$list_height" "$@" 3>&1 1>&2 2>&3) || return $?
    printf '%s' "$output"
  else
    local tags=() index=1 choices result=() choice
    while [[ "$#" -gt 0 ]]; do
      tags+=("$1")
      printf '%2d. [%s] %s - %s\n' "$index" "$3" "$1" "$2" >&2
      shift 3
      index=$((index + 1))
    done
    printf 'Select numbers separated by spaces: ' >&2
    read -r choices || return 1
    for choice in $choices; do
      [[ "$choice" =~ ^[0-9]+$ ]] || continue
      (( choice >= 1 && choice <= ${#tags[@]} )) || continue
      result+=("${tags[$((choice - 1))]}")
    done
    printf '%s' "${result[*]}"
  fi
}

flag_state() {
  [[ "${1:-0}" == "1" ]] && printf 'on' || printf 'off'
}
