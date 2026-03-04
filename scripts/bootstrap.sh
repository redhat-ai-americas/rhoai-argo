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
oc apply -f "${BOOTSTRAP_DIR}/gitops-permission.yaml"

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
# [4/6] Wait for ArgoCD Server & Enable Plugin
# -------------------------------------------------------------------
echo "[4/6] Finalizing GitOps environment..."

# Wait for server deployment
until oc get deployment openshift-gitops-server -n openshift-gitops &> /dev/null; do sleep 2; done
oc wait --for=condition=Available deployment/openshift-gitops-server -n openshift-gitops --timeout=300s
echo "  ✅ ArgoCD server is active."

# Check if the GitOps plugin is already enabled in the console
CURRENT_PLUGINS=$(oc get console.operator.openshift.io cluster -o jsonpath='{.spec.plugins}')

if [[ "$CURRENT_PLUGINS" == *"gitops-plugin"* ]]; then
    echo "  🎨 GitOps Console Plugin is already enabled. Skipping patch."
else
    echo "  🎨 Enabling GitOps Console UI Plugin..."
    
    # Ensure the plugin resource itself exists before trying to enable it
    until oc get consoleplugin gitops-plugin &> /dev/null; do
      echo "    ...waiting for gitops-plugin CR..."
      sleep 5
    done

    # Patch the console to add the plugin to the existing list
    oc patch console.operator.openshift.io cluster --type=merge -p '{"spec":{"plugins":["gitops-plugin"]}}'
    echo "  ✅ GitOps tab enabled. (Refresh your browser to see it)."
fi

# -------------------------------------------------------------------
# [5/6] Create the ArgoCD Applications
# -------------------------------------------------------------------
echo "[5/6] Deploying ArgoCD Stack Applications..."

APPS=(
    "network-operators.yaml"
    "observability-operators.yaml"
    "scaling-operators.yaml"
    "hardware-operators.yaml"
    "gpu-installation.yaml"
    "rhoai-application.yaml"
)

for app in "${APPS[@]}"; do
    if [ -f "${APPS_DIR}/${app}" ]; then
        echo "  Applying ${app}..."
        oc apply -f "${APPS_DIR}/${app}" -n openshift-gitops
    else
        echo "  ⚠️  Skipping ${app} (File not found)"
    fi
done

echo ""
echo "============================================"
echo "  Bootstrap Complete"
echo "============================================"