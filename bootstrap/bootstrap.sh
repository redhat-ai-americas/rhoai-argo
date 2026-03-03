#!/bin/bash
set -euo pipefail

# =============================================================================
# RHOAI Cluster Bootstrap Script
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="${SCRIPT_DIR}/../bootstrap"
APPS_DIR="${SCRIPT_DIR}/../helm/argocd-applications"

echo "============================================"
echo "  RHOAI Cluster Bootstrap"
echo "============================================"

# -------------------------------------------------------------------
# [1/6] Preflight checks
# -------------------------------------------------------------------
echo "[1/6] Preflight checks..."
if ! oc whoami &> /dev/null; then echo "ERROR: Run 'oc login' first."; exit 1; fi

# -------------------------------------------------------------------
# [2/6] Install GitOps & Permissions
# -------------------------------------------------------------------
echo "[2/6] Configuring OpenShift GitOps..."

if oc get subscription openshift-gitops-operator -n openshift-operators &> /dev/null; then
    echo "  ✅ Subscription already exists. Applying updated permissions..."
else
    echo "  🚀 Installing OpenShift GitOps Operator..."
    oc apply -f "${BOOTSTRAP_DIR}/openshift-gitops-subscription.yaml"
fi

# Apply permissions immediately (Idempotent)
echo "  🔐 Applying GitOps cluster permissions..."
oc apply -f "${BOOTSTRAP_DIR}/gitops-permissions.yaml"

# -------------------------------------------------------------------
# [3/6] Wait for CRDs
# -------------------------------------------------------------------
echo "[3/6] Waiting for GitOps environment to stabilize..."
until oc get crd argocds.argoproj.io &> /dev/null; do
  echo "  ...waiting for ArgoCD CRDs..."
  sleep 5
done
echo "  ✅ CRDs ready."

# -------------------------------------------------------------------
# [4/6] Wait for ArgoCD Server
# -------------------------------------------------------------------
echo "[4/6] Waiting for ArgoCD server deployment..."
# The operator creates the namespace 'openshift-gitops' automatically
until oc get deployment openshift-gitops-server -n openshift-gitops &> /dev/null; do sleep 2; done

oc wait --for=condition=Available deployment/openshift-gitops-server -n openshift-gitops --timeout=300s
echo "  ✅ ArgoCD server is active."

# -------------------------------------------------------------------
# [5/6] Create the ArgoCD Applications
# -------------------------------------------------------------------
echo "[5/6] Deploying ArgoCD Stack Applications..."

APPS=(
    "network-operators.yaml"
    "observability-operators.yaml"
    "gpu-installation.yaml"
    "rhoai-applications.yaml"
)

for app in "${APPS[@]}"; do
    if [ -f "${APPS_DIR}/${app}" ]; then
        echo "  Applying ${app}..."
        oc apply -f "${APPS_DIR}/${app}"
    else
        echo "  ⚠️  Skipping ${app} (File not found)"
    fi
done

echo ""
echo "============================================"
echo "  Bootstrap Complete"
echo "============================================"