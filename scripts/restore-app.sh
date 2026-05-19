#!/usr/bin/env bash
set -euo pipefail

FLUX_NAMESPACE="flux-system"
FLUX_KUSTOMIZATION="public-edge-apps"
JOB_TIMEOUT="${RESTORE_JOB_TIMEOUT:-30m}"
SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

APP=""
SNAPSHOT=""
SNAPSHOT_DATE=""

usage() {
  cat <<'EOF'
Usage: restore-app.sh --app <app> [--snapshot <id> | --date <prefix>]
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --app)
      APP="$2"
      shift 2
      ;;
    --snapshot)
      SNAPSHOT="$2"
      shift 2
      ;;
    --date)
      SNAPSHOT_DATE="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'error: unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

[ -n "$APP" ] || {
  printf 'error: --app is required\n' >&2
  exit 1
}

[ -z "$SNAPSHOT" ] || [ -z "$SNAPSHOT_DATE" ] || {
  printf 'error: use either --snapshot or --date, not both\n' >&2
  exit 1
}

if [ "$SNAPSHOT" = "latest" ]; then
  SNAPSHOT=""
fi

command -v kubectl >/dev/null 2>&1 || { printf 'error: kubectl not found\n' >&2; exit 1; }
command -v flux >/dev/null 2>&1 || { printf 'error: flux not found\n' >&2; exit 1; }
[ -n "${KUBECONFIG:-}" ] || { printf 'error: KUBECONFIG must be set\n' >&2; exit 1; }

APP_DIR="$REPO_ROOT/src/k8s/apps/$APP"
[ -d "$APP_DIR" ] || {
  printf 'error: app directory not found: %s\n' "$APP_DIR" >&2
  exit 1
}

APP_MANIFEST="$APP_DIR/restore-job.yaml"
[ -f "$APP_MANIFEST" ] || {
  printf 'error: restore manifest not found: %s\n' "$APP_MANIFEST" >&2
  exit 1
}

APP_NAMESPACE="$(awk '/^namespace:/ { print $2; exit }' "$APP_DIR/kustomization.yaml")"
[ -n "$APP_NAMESPACE" ] || {
  printf 'error: namespace not found in %s/kustomization.yaml\n' "$APP_DIR" >&2
  exit 1
}

APP_DEPLOYMENT="$APP"
APP_JOB_NAME="${APP}-restore"

ORIGINAL_REPLICAS="$(kubectl -n "$APP_NAMESPACE" get deployment "$APP_DEPLOYMENT" -o jsonpath='{.spec.replicas}')"
ORIGINAL_FLUX_SUSPEND="$(kubectl -n "$FLUX_NAMESPACE" get kustomization "$FLUX_KUSTOMIZATION" -o jsonpath='{.spec.suspend}' 2>/dev/null || true)"
[ "$ORIGINAL_FLUX_SUSPEND" = "true" ] || ORIGINAL_FLUX_SUSPEND="false"

SCALED_DOWN="false"
SUSPENDED_FLUX="false"

cleanup() {
  local exit_code=$?
  set +e

  if [ "$SCALED_DOWN" = "true" ]; then
    printf '==> Scaling deployment %s back to %s\n' "$APP_DEPLOYMENT" "$ORIGINAL_REPLICAS"
    kubectl -n "$APP_NAMESPACE" scale deployment "$APP_DEPLOYMENT" --replicas="$ORIGINAL_REPLICAS" >/dev/null
    if [ "$ORIGINAL_REPLICAS" != "0" ]; then
      kubectl -n "$APP_NAMESPACE" rollout status deployment "$APP_DEPLOYMENT" --timeout=5m >/dev/null 2>&1 || true
    fi
  fi

  if [ "$SUSPENDED_FLUX" = "true" ]; then
    printf '==> Resuming Flux kustomization %s\n' "$FLUX_KUSTOMIZATION"
    flux resume ks "$FLUX_KUSTOMIZATION" -n "$FLUX_NAMESPACE" >/dev/null
  fi

  exit "$exit_code"
}

trap cleanup EXIT

if [ "$ORIGINAL_FLUX_SUSPEND" != "true" ]; then
  printf '==> Suspending Flux kustomization %s\n' "$FLUX_KUSTOMIZATION"
  flux suspend ks "$FLUX_KUSTOMIZATION" -n "$FLUX_NAMESPACE" >/dev/null
  SUSPENDED_FLUX="true"
fi

printf '==> Scaling deployment %s to 0\n' "$APP_DEPLOYMENT"
kubectl -n "$APP_NAMESPACE" scale deployment "$APP_DEPLOYMENT" --replicas=0 >/dev/null
kubectl -n "$APP_NAMESPACE" rollout status deployment "$APP_DEPLOYMENT" --timeout=5m
SCALED_DOWN="true"

printf '==> Deleting any previous Job named %s\n' "$APP_JOB_NAME"
kubectl -n "$APP_NAMESPACE" delete job "$APP_JOB_NAME" --ignore-not-found >/dev/null

printf '==> Applying restore Job for %s\n' "$APP"
if [ -z "$SNAPSHOT" ] && [ -z "$SNAPSHOT_DATE" ]; then
  kubectl apply -f "$APP_MANIFEST" >/dev/null
else
  kubectl create --dry-run=client --validate=false -f "$APP_MANIFEST" -o yaml \
    | kubectl set env --local -f - SNAPSHOT_ID="$SNAPSHOT" SNAPSHOT_DATE="$SNAPSHOT_DATE" -o yaml \
    | kubectl apply -f - >/dev/null
fi

printf '==> Waiting for Job %s\n' "$APP_JOB_NAME"
if ! kubectl -n "$APP_NAMESPACE" wait --for=condition=complete --timeout="$JOB_TIMEOUT" "job/$APP_JOB_NAME"; then
  kubectl -n "$APP_NAMESPACE" logs "job/$APP_JOB_NAME" || true
  exit 1
fi

printf '==> Scaling deployment %s back to %s\n' "$APP_DEPLOYMENT" "$ORIGINAL_REPLICAS"
kubectl -n "$APP_NAMESPACE" scale deployment "$APP_DEPLOYMENT" --replicas="$ORIGINAL_REPLICAS" >/dev/null
if [ "$ORIGINAL_REPLICAS" != "0" ]; then
  kubectl -n "$APP_NAMESPACE" rollout status deployment "$APP_DEPLOYMENT" --timeout=5m
fi
SCALED_DOWN="false"

if [ "$SUSPENDED_FLUX" = "true" ]; then
  printf '==> Resuming Flux kustomization %s\n' "$FLUX_KUSTOMIZATION"
  flux resume ks "$FLUX_KUSTOMIZATION" -n "$FLUX_NAMESPACE" >/dev/null
  SUSPENDED_FLUX="false"
fi

printf '==> Restore completed for %s\n' "$APP"
