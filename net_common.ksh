PING_DELAY=3
DSELF=${DSELF:-$(dirname "${BASH_SOURCE[0]}")}
[ -e ${DSELF}/common.ksh ] && . ${DSELF}/common.ksh || echo "net_common: cannot source ${DSELF:-.}/common.ksh" 1>&2

host_responds(){
  typeset args="-4 -q -c 1 -w ${2:-${PING_DELAY}} ${1}"
  typeset cmd="timeout --preserve-status ${2:-${PING_DELAY}} ping ${args}"
  $cmd 1>/dev/null 2>&1 || ${cmd/-4 /-6 } 1>/dev/null 2>&1
}

function get_ip {
  typeset ip
  [ -n "${1}" ] && \
  ip=$(dig +short +timeout=1 ${1}) || \
  fatal "get_ip: need a hostname or IP"
  [ -n "${ip}" ] && echo $ip || return 1
}
