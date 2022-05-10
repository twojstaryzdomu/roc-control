log(){
  echo "${@}"
}

log_ne(){
  echo -ne "${@}"
}

# Throw an error
error(){
  echo "${@}" 1>&2
  return ${RC:-1}
}

error_ne(){
  echo -ne "${@}" 1>&2
  return ${RC:-1}
}

# Throw an error && exit
fatal(){
  echo "${@}" 1>&2
  case $- in *i*) return ${RC:-1};; *) exit ${RC:-1}; esac
}

# Debug output
debug(){
  [ -n "${DEBUG}" ] && echo "${@}" 1>&2
  :
}

# Use stdin as function input
# function & typeset required to prevent input variable overwriting external variables
function pipe_input {
  typeset input
  while read input; do
    "${@}" "${input}"
  done
}

# Shares external environment
pipe_input2(){
  while read __input; do
    "${@}" "${__input}"
  done
}

set_trace(){
  [ -n "${TRACE}" ] && set -x
}

# Set SIGINT trap to clean up after interrupted password prompt
set_trap(){
  debug "set_trap: prepping global trap to run \"${@}\""
  trap "trap - INT TERM; debug \"set_trap: running: \\\"${@}\\\"\"; stty echo 2>/dev/null; [ -n \"${DEBUG}\" ] && set -x; ${@}; exit; [ -n \"${DEBUG}\" ] && set +x" INT TERM
  [ -n "${DEBUG}" ] && trap -p
}

# Make sure only one process is running or bail out
check_process(){
  while [ $(pgrep -c -x ${1}) -gt 1 ]; do
    case "${2}" in
    [0-9]*)
      log "Another ${1} process is still running. Waiting for ${2} seconds ..."
      sleep ${2}
    ;;
    *)
      RC=2 fatal "Another ${1} process is already running.\nBailing out..."
    ;;
    esac
  done
}

# Variables defined dynamically in the script need to be escaped
function runner {
  typeset cmd
  while read cmd; do
    debug "Running: $cmd"
    if [ -z ${DEBUG} ]; then
      eval ${cmd}
    else
      eval ${cmd} 1>&2
    fi
    typeset rc=$?
    [ $rc -ne 0 ] && log "'$cmd' failed with status $rc" && exit $rc
  done
  return 0
}

# Verify vars are set
function check_vars {
  for v in ${@}; do
    typeset -n n="${v}"
    [ -z "${n}" ] && fatal "${SELF:+${SELF}: }${v} needs to be set"
  done
}

#
function run_remote_or_local {
  typeset selector=${1}
  shift
  if [ $# -gt 0 ]; then
    case ${selector} in
    *remote*)
      check_vars USER HOST
      ping -q -c 1 -w 3 $HOST 2>/dev/null 1>&2 && \
      ssh ${DISABLE_STRICT:+-o StrictHostKeyChecking=no -o CheckHostIP=no} ${USER}@${HOST} "${@}"
    ;;
    *|local)
      eval "${@}"
    ;;
    esac
  else
    fatal "${SELF:+${SELF}: }run_remote_or_local: command to run undefined"
  fi
}

function return_true_if {
  rc=$?
  read cmd statuses <<< ${@}
  for s in $statuses; do
    [ $rc -eq $s ] && debug "${cmd} valid status ${s}, returning status 0" && return
  done
  error "${cmd} status ${rc} didn't match any of ${statuses}"
  return $rc
}

function fix_ampersand {
  sed -e 's|\&|\\&|g'
}

fix_dot(){
  sed -e 's|\.|\\.|g'
}

function fix_sed_chars {
  typeset s x
  if [ $# -ne 1 ]; then
    read x
  else
    x="${1}"
  fi
  for s in '[' ']' '(' ')' '\{' '\}'; do
    x="${x//${s}/\\${s}}"
    #debug "fix_sed_chars: s = ${s}; x = ${x}"
  done
  #debug "fix_sed_chars: x = ${x}"
  echo "${x}"
}

to_lower(){
  tr '[:upper:]' '[:lower:]'
}

to_upper(){
  tr '[:lower:]' '[:upper:]'
}

capitalise(){
  sed 's/\w\+/\L\u&/g'
}

join_break_on_line(){
  sed -e ':a;0~'${1}'!{N;s/\n/'"${2:-;}"'/;ba}'
}

join_break_on_string(){
  sed -nE '/'${1}'/!{H;b};x;s/\n/\'${2:-;}'/g;2~1p'
}

print_times(){
  for ((j=0;j<${1};j++)); do
    log_ne ${2}
  done
}

hold_konsole(){
  case $(cat /proc/$PPID/comm) in konsole) echo; read -n 1 x?"Press any key to close the konsole window/tab"; exit;; esac
}
