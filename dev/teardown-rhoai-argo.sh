#!/usr/bin/env bash
# Full teardown of everything deployed by the rhoai-argo app-of-apps.
#
# Leaves alone: OpenShift GitOps, cert-manager (and its sandbox certs/issuers),
# Keycloak/RHBK, and openshift-monitoring/cluster-monitoring-config.
#
# Dry run by default. Pass --apply to actually delete.
#   ./teardown-rhoai-argo.sh            # print what would be deleted
#   ./teardown-rhoai-argo.sh --apply 2>&1 | tee teardown.log

set -uo pipefail

APPLY=0
[[ "${1:-}" == "--apply" ]] && APPLY=1
TIMEOUT=${TIMEOUT:-600s}
FAILED=()

run() {
  echo "+ $*"
  [[ $APPLY == 1 ]] || return 0
  "$@" || { echo "!! failed: $*"; FAILED+=("$*"); }
}
step() { echo; echo "================ $* ================"; }
del() { run oc delete --ignore-not-found --wait=true --timeout="$TIMEOUT" "$@"; }

# Delete every Subscription in a namespace together with its installed CSV.
remove_operators() {
  local ns=$1 sub csv
  for sub in $(oc get subscriptions.operators.coreos.com -n "$ns" -o name 2>/dev/null); do
    csv=$(oc get "$sub" -n "$ns" -o jsonpath='{.status.installedCSV}')
    del "$sub" -n "$ns"
    [[ -n $csv ]] && del csv "$csv" -n "$ns"
  done
}

# Delete one operator from a shared namespace (openshift-operators).
remove_operator() {
  local ns=$1 sub=$2 csv
  csv=$(oc get subscriptions.operators.coreos.com "$sub" -n "$ns" -o jsonpath='{.status.installedCSV}' 2>/dev/null)
  del subscriptions.operators.coreos.com "$sub" -n "$ns"
  [[ -n $csv ]] && del csv "$csv" -n "$ns"
  for ip in $(oc get installplan -n "$ns" -o json | jq -r --arg c "$csv" '.items[] | select(.spec.clusterServiceVersionNames | index($c)) | .metadata.name'); do
    del installplan "$ip" -n "$ns"
  done
}

delete_crds_by_label() {
  local sel
  for sel in "$@"; do
    [[ -z $(oc get crd -l "$sel" -o name) ]] && continue
    run oc delete crd -l "$sel" --wait=true --timeout="$TIMEOUT"
  done
}

# Remove webhook configurations whose service lives in one of the given
# namespaces, so leftovers can't block API calls once those services are gone.
cleanup_webhooks() {
  local re kind name
  re="^($(IFS='|'; echo "$*"))$"
  for kind in validatingwebhookconfiguration mutatingwebhookconfiguration; do
    for name in $(oc get "$kind" -o json | jq -r --arg re "$re" \
        '.items[] | select(any(.webhooks[]?; (.clientConfig.service.namespace // "") | test($re))) | .metadata.name'); do
      del "$kind" "$name"
    done
  done
}

delete_namespaces() {
  cleanup_webhooks "$@"
  del namespace "$@"
}

oc whoami >/dev/null || exit 1
echo "Cluster: $(oc whoami --show-server)  apply=$APPLY"

# ---------------------------------------------------------------------------
step "0. Argo Applications (non-cascading)"
APPS="rhoai-app-of-apps database-manager gpu-operator-installation inference-stack-operators
infrastructure-utility-operators observability-operators rhoai-deployment self-signed-certs
workload-scaling-operators"
for app in $APPS; do
  fin=$(oc get application "$app" -n openshift-gitops -o jsonpath='{.metadata.finalizers}' 2>/dev/null)
  if [[ -n $fin ]]; then
    echo "!! $app has finalizers ($fin); a delete would cascade. Aborting."
    exit 1
  fi
done
del application -n openshift-gitops $APPS

# ---------------------------------------------------------------------------
step "1. RHOAI custom resources (operator cleans up components)"
del maastenantconfig default-tenant -n models-as-a-service
del datasciencecluster default-dsc
del dscinitialization default-dsci

# ---------------------------------------------------------------------------
step "2. Gateways and routes"
del route maas-gateway-route -n openshift-ingress
del gateway.gateway.networking.k8s.io maas-default-gateway data-science-gateway -n openshift-ingress
del configmap maas-default-gateway-config -n openshift-ingress
del gatewayclass data-science-gateway-class

# ---------------------------------------------------------------------------
step "3. RHOAI operator, namespaces, CRDs"
remove_operators redhat-ods-operator
delete_namespaces redhat-ods-applications redhat-ods-monitoring redhat-ods-operator rhods-notebooks \
  rhoai-model-registries redhat-ai-gateway-infra models-as-a-service ai-tenants
delete_crds_by_label platform.opendatahub.io/part-of operators.coreos.com/rhods-operator.redhat-ods-operator
del crd notebooks.kubeflow.org

# ---------------------------------------------------------------------------
step "4. MaaS database (CloudNativePG)"
del clusters.postgresql.cnpg.io openshift-ai-maas -n maas-db
delete_namespaces maas-db
remove_operator openshift-operators cloudnative-pg
delete_crds_by_label operators.coreos.com/cloudnative-pg.openshift-operators

# ---------------------------------------------------------------------------
step "5. MaaS stack (Kuadrant/RHCL, Authorino, Limitador, DNS, LWS)"
del kuadrants.kuadrant.io kuadrant -n kuadrant-system
del authorinos.operator.authorino.kuadrant.io authorino -n kuadrant-system
del limitadors.limitador.kuadrant.io limitador -n kuadrant-system
del leaderworkersetoperators.operator.openshift.io cluster
remove_operators kuadrant-system
remove_operators openshift-lws-operator
delete_namespaces kuadrant-system openshift-lws-operator
delete_crds_by_label \
  operators.coreos.com/rhcl-operator.kuadrant-system \
  operators.coreos.com/authorino-operator.kuadrant-system \
  operators.coreos.com/limitador-operator.kuadrant-system \
  operators.coreos.com/dns-operator.kuadrant-system \
  operators.coreos.com/leader-worker-set.openshift-lws-operator
del crd leaderworkersets.leaderworkerset.x-k8s.io

# ---------------------------------------------------------------------------
step "6. GPU (NVIDIA GPU operator, NFD)"
del clusterpolicies.nvidia.com gpu-cluster-policy
del nodefeaturediscoveries.nfd.openshift.io nfd-instance -n openshift-nfd
remove_operators nvidia-gpu-operator
remove_operators openshift-nfd
delete_namespaces nvidia-gpu-operator openshift-nfd
delete_crds_by_label \
  operators.coreos.com/gpu-operator-certified.nvidia-gpu-operator \
  operators.coreos.com/nfd.openshift-nfd

# ---------------------------------------------------------------------------
step "7. Workload scaling (KEDA, JobSet, Kueue)"
del kedacontrollers.keda.sh keda -n openshift-keda
del jobsetoperators.operator.openshift.io cluster
del kueues.kueue.openshift.io cluster
remove_operators openshift-keda
remove_operators openshift-jobset-operator
remove_operators openshift-kueue-operator
delete_namespaces openshift-keda openshift-jobset-operator openshift-kueue-operator
delete_crds_by_label \
  operators.coreos.com/openshift-custom-metrics-autoscaler-operator.openshift-keda \
  operators.coreos.com/job-set.openshift-jobset-operator \
  operators.coreos.com/kueue-operator.openshift-kueue-operator
del crd jobsets.jobset.x-k8s.io \
  admissionchecks.kueue.x-k8s.io clusterqueues.kueue.x-k8s.io cohorts.kueue.x-k8s.io \
  localqueues.kueue.x-k8s.io multikueueclusters.kueue.x-k8s.io multikueueconfigs.kueue.x-k8s.io \
  provisioningrequestconfigs.kueue.x-k8s.io resourceflavors.kueue.x-k8s.io topologies.kueue.x-k8s.io \
  workloadpriorityclasses.kueue.x-k8s.io workloads.kueue.x-k8s.io

# ---------------------------------------------------------------------------
step "8. Observability (COO, OpenTelemetry, Tempo)"
remove_operators openshift-cluster-observability-operator
remove_operators openshift-opentelemetry-operator
remove_operators openshift-tempo-operator
delete_namespaces openshift-cluster-observability-operator openshift-opentelemetry-operator openshift-tempo-operator
delete_crds_by_label \
  operators.coreos.com/cluster-observability-operator.openshift-cluster-observability \
  operators.coreos.com/opentelemetry-product.openshift-opentelemetry-operator \
  operators.coreos.com/tempo-product.openshift-tempo-operator

# ---------------------------------------------------------------------------
step "9. Infrastructure (KMM)"
remove_operators openshift-kmm
delete_namespaces openshift-kmm
delete_crds_by_label operators.coreos.com/kernel-module-management.openshift-kmm

# ---------------------------------------------------------------------------
step "10. Self-signed certs"
del certificate selfsigned-ca -n cert-manager
del secret cert-manager-ca -n cert-manager
del clusterissuer ca-issuer selfsigned-issuer

# ---------------------------------------------------------------------------
step "Leftovers"
echo "-- Subscriptions:"; oc get subscriptions.operators.coreos.com -A --no-headers | awk '{print $1"/"$2}'
echo "-- Namespaces still present or terminating:"
oc get ns --no-headers | grep -E 'ods|rhoai|maas|models-as|ai-gateway|ai-tenants|kuadrant|nvidia|nfd|lws|kueue|keda|jobset|kmm|tempo|opentelemetry|cluster-observability' || echo "(none)"
echo "-- Matching CRDs:"
oc get crd --no-headers | awk '{print $1}' | grep -E 'opendatahub|kserve|kubeflow|ray\.io|kuadrant|cnpg|nvidia|nfd|kmm|keda|jobset|kueue|tempo|opentelemetry|rhobs|perses|leaderworkerset|feast|trustyai|mlflow|ogx|llm-d|sparkoperator' || echo "(none)"
if (( ${#FAILED[@]} )); then
  echo; echo "!! ${#FAILED[@]} command(s) failed:"; printf '   %s\n' "${FAILED[@]}"
  exit 1
fi
echo; echo "Done."
