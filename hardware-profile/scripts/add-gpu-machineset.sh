#!/bin/bash
set -e

# Default values
INSTANCE_TYPE="g6e.4xlarge"
REPLICAS=1

# Parse command-line parameters
while getopts "t:r:h" opt; do
  case $opt in
    t) INSTANCE_TYPE="$OPTARG" ;;
    r) REPLICAS="$OPTARG" ;;
    h) echo "Usage: $0 [-t instance_type] [-r replicas]"; exit 0 ;;
    \?) echo "Invalid option -$OPTARG" >&2; exit 1 ;;
  esac
done

echo "🔍 Finding an existing worker MachineSet..."
# Grab the first worker machineset by name to use as our template
SOURCE_MS=$(oc get machinesets -n openshift-machine-api -o name | grep worker | head -n 1 | cut -d/ -f2)

if [ -z "$SOURCE_MS" ]; then
    echo "❌ Error: Could not find a worker MachineSet to clone."
    exit 1
fi

# Append -gpu1 to the copied name
NEW_NAME="${SOURCE_MS}-gpu1"

echo "📋 Cloning $SOURCE_MS into $NEW_NAME..."

# Export the source MachineSet to JSON
oc get machineset "$SOURCE_MS" -n openshift-machine-api -o json > /tmp/source-ms.json

echo "⚙️ Injecting $INSTANCE_TYPE, labels, and taints..."

# Use jq to strip cluster-specific metadata and inject our GPU requirements
# We check for instanceType (AWS), vmSize (Azure), and machineType (GCP)
jq --arg NAME "$NEW_NAME" \
   --arg INSTANCE "$INSTANCE_TYPE" \
   --argjson REPLICAS "$REPLICAS" \
   '
   # 1. Strip unique identifiers that Kubernetes auto-generates
   del(.metadata.uid, .metadata.resourceVersion, .metadata.creationTimestamp, .metadata.generation, .status) |
   
   # 2. Update Names and Replicas
   .metadata.name = $NAME |
   .spec.replicas = $REPLICAS |
   .spec.selector.matchLabels["machine.openshift.io/cluster-api-machineset"] = $NAME |
   .spec.template.metadata.labels["machine.openshift.io/cluster-api-machineset"] = $NAME |
   
   # 3. Inject the GPU Instance Type dynamically based on the Cloud Provider
   (.spec.template.spec.providerSpec.value | 
      (if has("instanceType") then .instanceType = $INSTANCE else . end) | 
      (if has("vmSize") then .vmSize = $INSTANCE else . end) |
      (if has("machineType") then .machineType = $INSTANCE else . end)
   ) as $new_provider |
   .spec.template.spec.providerSpec.value = $new_provider |
   
   # 4. Add Node Labels for OpenShift AI and your custom GPU Role
   .spec.template.spec.metadata.labels["node-role.kubernetes.io/worker"] = "" |
   .spec.template.spec.metadata.labels["node-role.kubernetes.io/gpu"] = "" |
   .spec.template.spec.metadata.labels["cluster-api/accelerator"] = "nvidia" |
   
   # 5. Add Taints so normal workloads do not steal the expensive GPU nodes
   .spec.template.spec.taints = [{"key": "nvidia.com/gpu", "value": "present", "effect": "NoSchedule"}]
   ' /tmp/source-ms.json > /tmp/gpu-ms.json

echo "🚀 Applying new GPU MachineSet..."
oc apply -f /tmp/gpu-ms.json

echo "✅ Success! The new MachineSet $NEW_NAME has been created."
echo "⏳ Run 'oc get nodes -w' to watch the new node boot up with the 'gpu,worker' roles."