#!/bin/bash
set -e

# Dynamically locate the configs directory relative to this script
CONFIG_DIR="$(dirname "$0")/configs"
CONFIG_FILE="${CONFIG_DIR}/time-slicing-config.yaml"

echo "📂 Verifying configuration files..."
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: Could not find the time-slicing configuration at $CONFIG_FILE"
    exit 1
fi

echo "⚙️ Creating the Time-Slicing ConfigMap in nvidia-gpu-operator namespace..."
oc apply -f "$CONFIG_FILE"

echo "🔄 Patching the NVIDIA ClusterPolicy to apply the time-slicing configuration..."
# We patch the ClusterPolicy to tell the DevicePlugin to use the ConfigMap we just created
oc patch clusterpolicy gpu-cluster-policy --type='merge' -p '
{
  "spec": {
    "devicePlugin": {
      "config": {
        "name": "time-slicing-config",
        "default": "any"
      }
    }
  }
}'

echo "✅ Success! GPU Time-slicing has been enabled."
echo "⏳ Note: It may take a few minutes for the NVIDIA device plugin pods to restart and apply the new capacity."
echo "Run 'oc describe node <gpu-node-name>' to verify the new nvidia.com/gpu capacity (e.g., 8)."