#!/bin/ksh

SELF="$(basename "${0}")"
LSRC="$(readlink -e "$(which ${0})")"
LSELF="$(basename "${LSRC}")"
DSELF="$(dirname "${LSRC}")"

# If conf script exists, parse it
# overrrides any of the below variables
CONFFILE=${DSELF}/${LSELF%.ksh}.conf
[ -r ${CONFFILE} ] && . ${CONFFILE}
for f in '' net; do
  [ ! -e ${DSELF}/${f:+${f}_}common.ksh ] && echo "${SELF}: cannot source ${DSELF:-.}/${f:+${f}_}common.ksh" 1>&2 && exit 1 || . ${DSELF}/${f:+${f}_}common.ksh
done

[ -r ${LSRC%.ksh}.defaults ] && . ${LSRC%.ksh}.defaults || fatal "Unable to source defaults ${LSRC%.ksh}.defaults"

prefix=${SELF#*.}
self=${SELF%.${prefix}}
self=${self#*_}
MODE=${self%_*}
target=${self#${MODE}}
target=${target#_}
TARGET=${target:-${DEFAULT_TARGETS}}

stop="${CMD} unload-module"
start="${CMD} load-module"
check="${CMD} list modules short ${CMD_REDIRECT} | grep -Pc"
restart="pkill pulseaudio"

function log {
  typeset rc=$?
  LOG="${LOG:+${LOG}
}${@}"
  return $rc
}

function release_log {
  typeset rc=$?
  [ -n "${LOG}" ] && sed -e "s/^/${SELF}:/g" <<< "${LOG}" && unset LOG
  return $rc
}

function error {
  typeset rc=$?
  debug "${@}"
  return $rc
}

# Debug output
function debug {
  typeset rc=$?
  [ -n "${DEBUG}" ] && echo $@ 1>&2
  return $rc
}

function run_if_exists {
  if whence -q ${1}; then
    ${@} 1>/dev/null
  else
    error "${1} function missing"
  fi && echo "${ok:-ok}" || (typeset rc=$?; echo "${fail:-failed}"; return $rc)
}

show_ips(){
  eval "${check%c} -o \"${PCRE_MODULE_ARGS}\"" ${CMD_REDIRECT} | tr '\n' ' '
}

function check_local {
  typeset count count_all count_matched ip rc status s
  ip="${1}"
  set -o pipefail
  [ -z "${no_count}" ] && for ((try=0;try<2;try++)); do
    count_all=$(eval "${check} \"${PCRE_MODULE_ARGS}\s+$\"")
    case $? in 1) debug "Pulseaudio needs restart?"; eval ${START_LOCAL};; esac
  done
  count_matched=$(eval "${check} \"${MODULE_ARGS/ /\\s}${ip}\"")
  debug "check_local: ip=${ip}; no_count = ${no_count}; count_matched=${count_matched}; count_all=${count_all}; rc=${rc}"
  case ${count_all} in
  ${count_matched}*)
    count=${count_matched}
  ;;
  *)
    count=$((count_matched-count_all))
    rc=1
  ;;
  esac
  echo -ne $count
  ips=$(show_ips)
  s=${count#1}
  status="${count} ${MODULE} module${s:+s} loaded${ips:+ on ${ips}}"
  log "${status}"
  # return different status based on whether ip or no_count is set
  [ -n "${no_count}" ] && return ${count_matched}
  [ -n "${ip}" ] && return ${rc:-0} || ok="${status}"
  return $((count_matched-count_all))
}

dump_volume(){
  ${PACMD} dump | grep '^set-sink-volume roc_sender' > ${VOLUME_FILE}
}

function restore_volume {
  if [ -f "${VOLUME_FILE}" ]; then
    eval ${PACMD} < "${VOLUME_FILE}" ${CMD_REDIRECT}
    typeset rc=$?
    [ $? -eq 0 ] && rm "${VOLUME_FILE}"
  fi
  return ${rc:-0}
}

function start_local {
  typeset count m output rc stale_ip v
  until output=$(check_local "${IP}"); do
    read count stale_ip <<< "${output}"
    debug "start_local: check_local: output=${output}; count=${count}"
    log "${count#-} too many ${MODULE} modules / with stale IP${stale_ip:+ (${stale_ip})}, reloading on ${IP}"
    ${stop} ${MODULE}
  done
  rc=$?
  v=$((${output% *}-(${1:-1})))
  m=${1:+opp}
  m=${m:-art}
  debug "start_local: output=${output}; rc=${rc}; \$IP=${IP}; v=${v}; \$1=${1}"
  case $v in
  0) log "${IP:+${output} }${MODULE} module already st${m}ed${IP:+ on ${IP}}";;
  [1-9]*)
    debug "St${m}ing"
    eval ${stop} ${MODULE} ${CMD_REDIRECT} && check_local "${IP}"
  ;;
  -[1-9]*)
    debug "St${m}ing"
    [ -n "${IP}" ] && eval ${start} ${MODULE_ARGS}${IP} ${CMD_REDIRECT} && restore_volume || log "refusing to start with no IP ${IP}"
  ;;
  esac 2>/dev/null 1>&2
}

stop_local(){
  dump_volume
  start_local 0
}

update_local(){
  [ -w "${PACONFIG}" ] || fatal "${PACONFIG} does not exist or is not writable by ${USER}"
  sed -i "/^load-module ${MODULE_ARGS}$/d" "${PACONFIG}"
  grep -Pq "${PCRE_MODULE_ARGS}" "${PACONFIG}" && \
  ([ -n "${IP}" ] && perl -i -pe  "s/${PCRE_MODULE_ARGS}/${IP}/g" "${PACONFIG}") || \
  ([ -n "${IP}" ] && echo "load-module ${MODULE_ARGS}${IP}" >> "${PACONFIG}" || sed -i "/^load-module ${MODULE_ARGS}/d" "${PACONFIG}")
}

function reload_local {
  typeset check_status s
  no_count=1 check_local
  check_status=$?
  debug "reload_local: check_status=${check_status}"
  update_local && \
  start_local && \
  case $check_status in
  1) :;;
  *)
    s=${check_status#1}
    ok="${check_status} ${MODULE} module${s:+s} running before ${MODE}${ips:+ on ${ips}}"
  esac
}

toggle(){
  ok="${1/p/pp}ed${2:+ on ${2}}"
  ${1}_${t}
}

toggle_local(){
  no_count=1 check_local && mode=start || mode=stop
  toggle ${mode}
}

function check_remote {
  debug "check_remote: REMOTE_HOST = ${REMOTE_HOST}; REMOTE_CMD = ${REMOTE_CMD} ${check} ${REMOTE_MODULE}"
  typeset count ips rc s status;
  if host_responds ${REMOTE_HOST} ${DELAY}; then
    count=$(eval ${REMOTE_CMD} ${check} ${REMOTE_MODULE}); rc=$?
    ips=$(show_ips)
    s=${count#1}
    status="${count} ${REMOTE_MODULE} module${s:+s} loaded${ips:+ on ${ips}}"
    case $MODE in
    check)
      fail="${status}"
    ;&
    *) log "${status}"
    esac
  else
    rc=$?
    fail="failed, unable to ${c:-ping} ${REMOTE_HOST}"
  fi
  return $rc
}

start_remote(){
  if ! check_remote; then
    eval_if_responds ${REMOTE_CMD} ${start} ${REMOTE_MODULE} ${REMOTE_MODULE_ARGS} ${CMD_REDIRECT} 1>/dev/null
    check_remote
  fi
}

function eval_if_responds {
  if host_responds ${REMOTE_HOST} ${DELAY}; then
    debug "eval_if_responds: ${@}"
    eval $@
  else
    typeset rc=$?
    echo "failed, unable to ${c:-ping} ${REMOTE_HOST}"
    [ -z "${FORCE}" ] && exit $rc || return $rc
  fi
}

stop_remote(){
  eval_if_responds ${REMOTE_CMD} ${stop} ${REMOTE_MODULE} ${CMD_REDIRECT}
}

prep_remote(){
  eval_if_responds 'c=resolve && IP=$(get_ip "${REMOTE_HOST}")'
  debug "prep_remote: IP=${IP}"
}

update_remote(){
  ok="not implemented"
}

reload_remote(){
  stop_remote && \
  sleep ${DELAY} && \
  start_remote
}

toggle_remote(){
  no_count=1 check_local && mode=stop || mode=start
  toggle ${mode} "${REMOTE_HOST} (${IP})"
}

FORCE=${FORCE:+ }
debug "MODE = ${MODE}; TARGET = ${TARGET}; REMOTE_HOST = ${REMOTE_HOST}; FORCE is ${FORCE:-not }set"

check_process "${LSELF}"
case ${MODE} in
check)
  check=${check/-q}
;;
start|stop|update|reload|toggle)
  prep_remote
;;
${self})
  fatal "Cannot run as ${self}"
;;
esac
for t in ${TARGET}; do
  echo -n "$(sed -e 's|^.|\U&|g;s|p$|&&|g;s|e$||g' <<< "${MODE}")ing roc on ${t}: "
  run_if_exists ${MODE}_${t}
  debug "${MODE}_${t}: $?"
  release_log 1>&2
done
