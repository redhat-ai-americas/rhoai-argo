#!/bin/bash
set -e

echo "⬇️ Downloading the latest NVIDIA DCGM Exporter Dashboard..."
curl -Lf https://github.com/NVIDIA/dcgm-exporter/raw/main/grafana/dcgm-exporter-dashboard.json -o /tmp/dcgm-exporter-dashboard.json

echo "🧹 Cleaning up any existing dashboard configmaps..."
oc delete configmap nvidia-dcgm-exporter-dashboard -n openshift-config-managed --ignore-not-found

echo "🛠️ Creating the ConfigMap in openshift-config-managed..."
oc create configmap -n openshift-config-managed nvidia-dcgm-exporter-dashboard \
  --from-file=nvidia-dcgm-dashboard.json=/tmp/dcgm-exporter-dashboard.json

echo "🏷️ Labeling the ConfigMap for the Administrator perspective..."
oc label configmap nvidia-dcgm-exporter-dashboard -n openshift-config-managed "console.openshift.io/dashboard=true"

echo "🏷️ Labeling the ConfigMap for the Developer perspective..."
oc label configmap nvidia-dcgm-exporter-dashboard -n openshift-config-managed "console.openshift.io/odc-dashboard=true"

echo "✅ Success! Here are the final labels for the dashboard:"
oc -n openshift-config-managed get cm nvidia-dcgm-exporter-dashboard --show-labels