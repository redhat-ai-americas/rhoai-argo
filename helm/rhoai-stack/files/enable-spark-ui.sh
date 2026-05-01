#!/bin/bash
set -euo pipefail

NAMESPACE="spark-operator"
DEPLOYMENT="spark-operator-controller"

# Remove ownerReferences so the deployment survives operator reconciliation.
# Tolerate the field already being absent (e.g. on a retry).
oc patch "deployment/${DEPLOYMENT}" -n "${NAMESPACE}" \
  --type=json -p='[{"op": "remove", "path": "/metadata/ownerReferences"}]' 2>/dev/null \
  || echo "ownerReferences already absent, continuing."

sleep 3

# Idempotency: exit early if ingress args were already patched
CURRENT_ARGS=$(oc get "deployment/${DEPLOYMENT}" -n "${NAMESPACE}" \
  -o jsonpath='{range .spec.template.spec.containers[0].args[*]}{@}{"\n"}{end}' 2>/dev/null || true)

if echo "${CURRENT_ARGS}" | grep -qF "ingress-url-format"; then
  echo "Spark UI ingress args already present, nothing to do."
  exit 0
fi

# Derive the cluster wildcard domain from the console route
CONSOLE_HOST=$(oc get route console -n openshift-console -o jsonpath='{.spec.host}')
if [ -z "${CONSOLE_HOST}" ]; then
  echo "ERROR: Could not resolve console route host." >&2
  exit 1
fi
CLUSTER_DOMAIN="${CONSOLE_HOST#*.apps}"
INGRESS_DOMAIN=".apps${CLUSTER_DOMAIN}"

# {{$appName}} and {{$appNamespace}} are Go template vars resolved by the Spark operator
INGRESS_URL_ARG='--ingress-url-format=https://{{$appName}}-{{$appNamespace}}'"${INGRESS_DOMAIN}"
INGRESS_TLS_ARG='--ingress-tls=[{}]'

# Append to existing args; fall back to creating the args array if it is absent
if ! oc patch "deployment/${DEPLOYMENT}" -n "${NAMESPACE}" --type=json \
  -p="[
    {\"op\": \"add\", \"path\": \"/spec/template/spec/containers/0/args/-\", \"value\": \"${INGRESS_URL_ARG}\"},
    {\"op\": \"add\", \"path\": \"/spec/template/spec/containers/0/args/-\", \"value\": \"${INGRESS_TLS_ARG}\"}
  ]" 2>/dev/null; then

  echo "args field missing on container, creating it..."
  oc patch "deployment/${DEPLOYMENT}" -n "${NAMESPACE}" --type=json \
    -p="[{\"op\": \"add\", \"path\": \"/spec/template/spec/containers/0/args\", \"value\": [\"${INGRESS_URL_ARG}\", \"${INGRESS_TLS_ARG}\"]}]"
fi

echo "Spark UI ingress configuration applied successfully."