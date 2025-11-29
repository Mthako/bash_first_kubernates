#!/usr/bin/env bash
set -euo pipefail

KUBECTL=${KUBECTL:-kubectl}
DRY_RUN=${DRY_RUN:-true}

log() {
  echo "[kube-tool] $*" >&2
}

kt::run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log "DRY-RUN: $*"
  else
    log "RUNNING: $*"
    "$@"
  fi
}

kt::list_pods() {
  local ns=${1:-default}
  ${KUBECTL} get pods -n "$ns" -o json
}

kt::scale_deployment() {
  local ns=$1
  local deployment=$2
  local replicas=$3

  # Safety check: prevent scaling critical to zero
  local critical=$(${KUBECTL} -n "$ns" get deployment "$deployment" -o jsonpath='{.metadata.annotations.kubeintellect/critical}' 2>/dev/null || echo "")
  if [[ "$replicas" -eq 0 && "$critical" == "true" ]]; then
    log "Refusing to scale critical deployment '$deployment' to 0 replicas"
    return 1
  fi

  kt::run ${KUBECTL} -n "$ns" scale deployment "$deployment" --replicas="$replicas"
}

kt::rollout_restart() {
  local ns=$1
  local deployment=$2
  kt::run ${KUBECTL} -n "$ns" rollout restart deployment "$deployment"
}

kt::logs_follow() {
  local ns=$1
  local pod_selector=$2
  ${KUBECTL} -n "$ns" logs -l "$pod_selector" -f
}

kt::port_forward() {
  local ns=$1
  local svc=$2
  local local_port=$3
  local remote_port=$4
  ${KUBECTL} -n "$ns" port-forward svc/"$svc" "$local_port":"$remote_port"
}
