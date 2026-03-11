# rhoai-argo

Deployment of **Red Hat OpenShift AI (RHOAI)** and its required infrastructure stack using Helm and ArgoCD.

---

## 🚀 Getting Started

To initialize RHOAI, install OpenShift GitOps, configure permissions, and trigger the **App-of-Apps** deployment.

### 0. Clone the Repository
```bash
git clone https://github.com/redhat-ai-americas/rhoai-argo.git
cd rhoai-argo
```

### 1. Prepare OpenShift GitOps
- Check if the OpenShift GitOps Subscription exists. If not, apply it and configure permissions for the Service Account once the operator is ready.

```bash
# 1. Install Operator (only if missing) & Permissions
oc get subscription openshift-gitops-operator -n openshift-operators &>/dev/null || oc apply -f gitops-config/openshift-gitops-subscription.yaml
oc apply -f gitops-config/gitops-permission.yaml

echo "⏳ Finalizing OpenShift GitOps environment..."

# 2. Silent Wait until the Deployment exists
until oc wait deployment/openshift-gitops-server -n openshift-gitops --for=condition=Available --timeout=10s &>/dev/null; do sleep 5; done

# 3. Apply custom health checks and enable the sidebar GitOps tab
oc apply --server-side --force-conflicts -f gitops-config/argocd-instance.yaml
```

---

## 📦 2. Trigger "App-of-Apps" Deployment

- Choose one of the following installation strategies. Both use the **App-of-Apps** pattern with sync waves, which you can find the details of down below.

### Option A: Default Installation (Manual Approval)
- Operators will require manual approval for any version upgrades in the OpenShift Console.
```bash
oc apply -f app-of-apps.yaml
```

### Option B: Automatic Update Installation
- This allows the cluster to automatically handle future patches for dependencies (Hardware, Network, etc.). **Note:** RHOAI itself will remain on Manual approval.

```bash
sed 's/installPlanApproval: Manual/installPlanApproval: Automatic/' app-of-apps.yaml | oc apply -f -
```

---

## 🖥️ 3. Monitor and Approve Installation

- The ArgoCD dashboard is available via the **Waffle Menu** in the OpenShift Console header. Alternatively, retrieve the URL directly:

```bash
# Get the ArgoCD URL
oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}'
```

### Approve InstallPlans
> [!NOTE]
> You must approve the RHOAI InstallPlan once it requests approval. If you chose **Option A**, you must also approve all infrastructure dependencies.


1. In the OpenShift Dashboard, navigate to **Home > Search**.
2. Type **"InstallPlan"** in the search bar and select the resource type.
3. Initiate operator installations by clicking **Installxxxxx > Preview InstallPlan > Approve**.

---

> [!NOTE]
> The Service Mesh Operator, automatically installed by RHOAI, is not the most current version. The update/InstallPlan to the latest version can be ignored.


> [!TIP]
> **Bulk Approval:** To approve all currently waiting InstallPlans at once (the additional Servish Mesh version does not break anything), run:
> ```bash
> oc get installplan -A --no-headers | grep "false" | awk '{print $1, $2}' | xargs -L1 sh -c 'oc patch installplan $1 -n $0 --type merge -p "{\"spec\":{\"approved\":true}}"'
> ```

**Wait for the `rhoai-deployment` ArgoCD application to reach a Healthy state, and... Enjoy using RHOAI!**

---

## 🛠️ 4. Manual Post-Sync Steps

**Some steps are cluster-specific and cannot be fully automated via GitOps:**

1. **GPU MachineSet:** Create a GPU worker MachineSet for your cloud provider. See [Enable GPU Support Docs](https://github.com/redhat-ai-americas/rhoai-installation-workshop/blob/main/docs/02-enable-gpu-support.md).
2. **Hardware Profile:** Create a Hardware Profile in the RHOAI dashboard:
   - **Settings > Hardware profiles > Create hardware profile**
   - Add resource: `nvidia.com/gpu` (Default: 1, Min: 1, Max: 1)
   - Add toleration: Operator: `Exists`, Effect: `NoSchedule`, Key: `nvidia.com/gpu`
   - Ref: [RHOAI 3.2 Hardware Profiles](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.2/html/working_with_accelerators/working-with-hardware-profiles_accelerators).
3. **GPU Node Taints (Optional):** Prevent non-GPU workloads from scheduling on GPU nodes. See [Configure GPU Sharing](https://github.com/redhat-ai-americas/rhoai-installation-workshop/blob/main/docs/05-configure-gpu-sharing-method.md).

---

## RHOAI 3.x Dependencies

| Operator | Description |
| :--- | :--- |
| **[Job-set](https://catalog.redhat.com/en/software/containers/job-set/jobset-rhel9/67ff5fff0c2e671dd4fb967b)** | Kubernetes-native API for managing groups of jobs as a unit |
| **[openshift-custom-metrics-autoscaler](https://docs.redhat.com/en/documentation/openshift_container_platform/4.12/html/nodes/automatically-scaling-pods-with-the-custom-metrics-autoscaler-operator)** | Custom Metrics Autoscaler Operator |
| **[cert-manager](https://cert-manager.io/docs/)** | Cert-manager Operator for Red Hat OpenShift |
| **[Leader Worker Set](https://catalog.redhat.com/en/software/containers/leader-worker-set/lws-rhel9-operator/67ff5ba672750ac769022fd6)** | LWS-rhel9 Operator |
| **[Red Hat Connectivity Link](https://docs.redhat.com/en/documentation/red_hat_connectivity_link/1.0)** | Unified framework for multicloud connectivity and API management |
| **[Kueue (RHBOK)](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/ai_workloads/red-hat-build-of-kueue)** | Red Hat Build of Kueue |
| **[SR-IOV](https://docs.redhat.com/en/documentation/openshift_container_platform/4.12/html/networking/hardware-networks)** | Single Root I/O Virtualization (SR-IOV) Network Operator |
| **[GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/index.html)** | NVIDIA GPU provisioning and management |
| **[OpenTelemetry](https://opentelemetry.io/)** | Vendor-neutral observability framework for metrics, logs, and traces |
| **[Tempo](https://catalog.redhat.com/en/software/container-stacks/detail/64254fc5060863e2125a6186)** | High-scale distributed tracing backend |
| **[Cluster Observability](https://docs.redhat.com/en/documentation/red_hat_openshift_cluster_observability_operator/1-latest)** | Standalone monitoring stacks for independent service configuration |

## Sync Wave Architecture

| Sync Wave | Summary | Resources |
|-----------|-----------|-------------|
| 0 | Namespaces | All operators |
| 5 | RHOAI Dependencies & Utilities | job-set-operator, cma-operator, cert-manager, leader-worker-set, Kueue, SR-IOV, OpenTelemetry, Tempo, ClusterObservability, kmm  |
| 7 | Configs | cluster-job-set, cma-controller|
| 10 | GPU Dependencies & Hardware Operators| nfd-operator|
| 15 | Configs | nfd-instance |
| 20 | NVIDIA GPU Operator| gpu-operator |
| 25 | GPU Cluster Policy | gpu-clusterpolicy |
| 30 | RHOAI Operator Group + Subscription | rhoai-operator |
| 32 | RHOAI Deployment | operator-deployment |
| 33 | DataScienceCluster resource configuration for RHOAI | datasciencecluster |
| 35 | RHOAI dashboard configuration | odhdashboardconfig |

---

## References

* [Upstream OpenShift AI Setup Reference](https://github.com/jharmison-redhat/openshift-setup/tree/main/charts/openshift-ai/templates)

## Repository Structure

```
rhoai-argo/
├── app-of-apps.yaml
├── README.md
├── gitops-config/
│   ├── gitops-permission.yaml
│   └── openshift-gitops-subscription.yaml
├── argocd-applications/
│   ├── Chart.yaml
│   └── templates/
│       ├── gpu-installation.yaml
│       ├── network-operators.yaml
│       ├── observability-operators.yaml
│       ├── rhoai-application.yaml
│       └── scaling-operators.yaml
└── helm/
    ├── rhoai-stack/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    │       ├── configs/
    │       │   ├── 32-operator-deployment.yaml
    │       │   ├── 33-datasciencecluster.yaml
    │       │   ├── 35-dashboard-deployment.yaml
    │       │   └── 35-odhdashboardconfig.yaml
    │       └── operators/
    │           └── 30-rhoai-operator.yaml
    ├── workload-scaling/
    │   ├── Chart.yaml
    │   └── templates/
    │       ├── configs/
    │       │   ├── 07-cluster-job-set.yaml
    │       │   └── 07-cma-controller.yaml
    │       └── operators/
    │           ├── 05-cma-operator.yaml
    │           ├── 05-job-set.yaml
    │           ├── 05-leader-worker-set.yaml
    │           └── 05-rhbok.yaml
    ├── gpu-installation/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    │       ├── configs/
    │       │   ├── 15-nfd-instance.yaml
    │       │   └── 25-gpu-clusterpolicy.yaml
    │       └── operators/
    │           ├── 10-nfd-operator.yaml
    │           └── 20-gpu-operator.yaml
    ├── network-fabric/
    │   ├── Chart.yaml
    │   └── templates/
    │       ├── configs/
    │       └── operators/
    │           ├── 05-kmm.yaml
    │           ├── 05-rhcl.yaml
    │           └── 05-sriov.yaml
    └── observability-stack/
        ├── Chart.yaml
        └── templates/
            ├── configs/
            └── operators/
                ├── 05-cluster-observability.yaml
                ├── 05-open-telemetry.yaml
                └── 05-tempo.yaml
```