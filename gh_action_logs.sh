#!/bin/env bash

# A simple Bash script to delete GitHub actions logs

# Reference:
# https://github.blog/changelog/2020-04-21-github-actions-logs-can-now-be-deleted/
# https://docs.github.com/en/rest/actions/workflow-runs?apiVersion=2022-11-28#list-workflow-runs-for-a-repository
# https://docs.github.com/en/rest/actions/workflow-runs?apiVersion=2022-11-28#delete-workflow-run-logs

TIMESTAMP="$(date '+%Y-%m-%d_%Hh%Mm%Ss')"
LOG_PATH=
LOG_FILE=

# Token must have admin rights over the repo as we're going to delete the logs
# https://github.com/settings/tokens
TOKEN=
OWNER=
REPO=
RUN_ID_LIST=()

panic() {
  [[ $1 ]] && echo "Error: $*"
  [[ -f "$LOG_FILE" && ! -s "$LOG_FILE" ]] && rm -I "$LOG_FILE"
  exit 1
}

prepare_log_file() {
  [[ "$LOG_PATH" ]] || LOG_PATH="$PWD"
  [[ "$LOG_FILE" ]] || LOG_FILE="gh_logs-$TIMESTAMP.json"
  local ACCEPT DEF_P="$LOG_PATH" DEF_F="$LOG_FILE"

  while :; do
    [[ "$LOG_PATH" ]] || { echo -n "Enter PATH for saving the logs: " && read -r LOG_PATH; }
    [[ "$LOG_FILE" ]] || { echo -n "Enter filename for the log file: " && read -r LOG_FILE; }

    [[ "$LOG_PATH" ]] || LOG_PATH="$DEF_P"
    [[ "$LOG_FILE" ]] || LOG_FILE="$DEF_F"
    echo -e "\nPATH: $LOG_PATH\nLOG FILE: ${LOG_FILE##*/}"
    echo -ne "\nIs this correct? [Y/n] " && read -r ACCEPT

    if [[ $ACCEPT =~ ^[YySs] || -z $ACCEPT ]]; then
      LOG_FILE="$LOG_PATH/$LOG_FILE"
      [[ -d "$LOG_PATH" ]] && :>>"$LOG_FILE" 2>/dev/null && break
      echo "The \`PATH\` and/or \`filename\` provided are not valid. Try again."
    fi
    LOG_PATH='' LOG_FILE=''
  done
}

prepare_gh_info() {
  local ACCEPT DEF_T=$TOKEN DEF_O=$OWNER DEF_R=$REPO
  while :; do
    [[ $TOKEN ]] || { echo -n "Enter TOKEN: " && read -r TOKEN; }
    [[ $OWNER ]] || { echo -n "Enter GitHub username: " && read -r OWNER; }
    [[ $REPO  ]] || { echo -n "Enter GitHub repository: " && read -r REPO; }

    [[ $TOKEN ]] || TOKEN=$DEF_T
    [[ $OWNER ]] || OWNER=$DEF_O
    [[ $REPO  ]] || REPO=$DEF_R

    echo -e \
      "\nTOKEN: $TOKEN" \
      "\nUsername: $OWNER" \
      "\nRepository: $REPO"

    echo -ne "\nIs this correct? [Y/n] " && read -r ACCEPT
    [[ $ACCEPT =~ ^[YySs] || -z $ACCEPT ]] && break
    TOKEN='' OWNER='' REPO=''
  done
}

get_logs() {
  if [[ -s "$LOG_FILE" ]]; then
    local ACCEPT
    echo -n "LOG_FILE already exists. Overwrite? [y/N] " && read -r ACCEPT
    [[ $ACCEPT =~ ^[YySs] ]] || return
  fi

  [[ -d "$LOG_PATH" ]] || { echo "${FUNCNAME[0]}(): invalid path for logs"; return; }
  [[ $TOKEN && $OWNER && $REPO ]] || { echo "${FUNCNAME[0]}(): credentials mismatch"; return; }
  [[ $DRY_RUN && -s "$LOG_FILE" ]] && { echo "Dry run. Skipping LOG_FILE overwrite..."; return; }
  curl -L \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/$OWNER/$REPO/actions/runs" > "$LOG_FILE"
}

filter_logs() {
  [[ -s "$LOG_FILE" ]] || { echo "${FUNCNAME[0]}(): invalid log file"; return; }
  awk '/"id":/{print $2}' "$LOG_FILE" | sed 's/\(\"\|,\)//g'
}

delete_action_logs() {
  [[ $1 ]] && local RUN_ID="$1" || return

  echo "Deleting logs for $RUN_ID"
  [[ $TOKEN && $OWNER && $REPO ]] || { echo "${FUNCNAME[0]}(): credentials mismatch"; return; }
  [[ $DRY_RUN ]] && { echo "Dry run. Skipping ${FUNCNAME[0]}()..."; return; }
  curl -L \
    -X DELETE \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $TOKEN" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/$OWNER/$REPO/actions/runs/$RUN_ID/logs"
}

delete_all_logs() {
  local DELETE_ALL
  echo -ne \
    "\nWarning: this will delete all logs for all GitHub actions runs" \
    "for the provided repository.\nAre you sure you want to continue?" \
    "Type YES (with capital letters): " && read -r DELETE_ALL

  [[ $DELETE_ALL == 'YES' ]] || { echo "Aborting..." && return; }

  for i in "$@"; do
    delete_action_logs "$i"
    echo
  done
}

main() {
  [[ $1 == '--dry-run' ]] && DRY_RUN=1

  prepare_log_file
  prepare_gh_info
  get_logs

  [[ -s "$LOG_FILE" ]] || { panic "getting logs"; }
  RUN_ID_LIST+=($(filter_logs))
  [[ "${RUN_ID_LIST[*]}" ]] || { panic "parsing logs"; }

  delete_all_logs "${RUN_ID_LIST[@]}"
}

main "$@"
