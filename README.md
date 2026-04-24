# rhoai-argo

Deployment of **Red Hat OpenShift AI (RHOAI)** and its required infrastructure stack using Helm and ArgoCD.

## Automation Architecture

| Sync Wave | Description | Resources |
|-----------|-----------|-------------|
| 0 | Namespaces | All operators |
| 5 | RHOAI Dependencies & Utilities | job-set-operator, cma-operator, cert-manager, leader-worker-set, Kueue, SR-IOV, OpenTelemetry, Tempo, ClusterObservability, kmm  |
| 7 | Configs | cluster-job-set, cma-controller|
||
| *Checkpoint* | 
||
| 10 | GPU Dependencies & Hardware Operators| nfd-operator|
| 15 | Configs | nfd-instance |
| 20 | NVIDIA GPU Operator| gpu-operator |
| 25 | GPU Cluster Policy | gpu-clusterpolicy |
||
| *Checkpoint* | 
||
| 30 | RHOAI Operator Group + Subscription | rhoai-operator |
| 32 | RHOAI Deployment | operator-deployment |
| 33 | DataScienceCluster configuration | datasciencecluster |
| 35 | RHOAI dashboard configuration | odhdashboardconfig |

---

## 🚀 Getting Started

To initialize RHOAI, install OpenShift GitOps, configure permissions, and trigger the **App-of-Apps** deployment.

### 0. Clone the Repository
```bash
git clone https://github.com/redhat-ai-americas/rhoai-argo.git
cd rhoai-argo
```

### 1. Prepare OpenShift GitOps (~60 seconds)
- Checks if the OpenShift GitOps Subscription exists. If not, applies it and configures permissions for the Service Account once the operator is **fully** ready.

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

- Apply the yaml file for our **App-of-Apps** pattern controlled via sync waves.

### Installation (Manual Approval)
- Operators will require manual approval for any version upgrades in the OpenShift Console.
```bash
oc apply -f app-of-apps.yaml
```

---

### Approve InstallPlans
> [!NOTE]
> You must approve the InstallPlan requests as they attempt to install. This is to avoid automatic updates on your AI workloads. In order to use Automatic updates, first push this to an empty repository and update the app templates to point to git url. Then, change the end of the first line in *argocd-applications/values.yaml* from **Manual** to **Automatic**

1. In the OpenShift Dashboard, navigate to **Home > Search**.
2. The search bar, where it says *Resources*, type **"InstallPlan"** select the resource type.
3. Click on the InstallPlan name in the first column, **Installxxxxx > Preview InstallPlan > Approve**. (Or use the tip below)
4. To get back to the list, click on **InstallPlans** in the path at the top left. **Make sure** you are on **all projects** from the namespace dropdown menu at the top of the screen to see all InstallPlans.

> [!TIP]
> **Bulk Approval:** To approve all currently waiting InstallPlans at once, run:
> ```bash
> oc get installplan -A --no-headers | grep "false" | awk '{print $1, $2}' | xargs -L1 sh -c 'oc patch installplan $1 -n $0 --type merge -p "{\"spec\":{\"approved\":true}}"'
> ```
>
> **Rolling Approval:** To approve all pending and future InstallPlans, run:
> ```bash
> oc get installplan -A -w -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase --no-headers | while read -r namespace name phase; do
>      if [ "$phase" = "RequiresApproval" ]; then
>       echo "Detected ready InstallPlan: $name in $namespace. Approving..."
>       oc patch installplan "$name" -n "$namespace" --type merge -p '{"spec":{"approved":true}}'
>   fi
> done
> ```


---

## 🖥️ 3. Monitor ArgoCD

- The ArgoCD dashboard is available via the **Waffle Menu** in the OpenShift Console header. Alternatively, retrieve the URL directly:

```bash
# Get the ArgoCD URL
oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}'
```



**Wait for the `rhoai-deployment` ArgoCD application to reach a Healthy state, and... Enjoy using RHOAI!**

---

## 🛠️ 4. Configure Hardware (Optional)

If your workloads require GPU acceleration, navigate to the `hardware-profile/` directory. This folder contains automation scripts and documentation to streamline your GPU setup rather than relying on manual cluster configurations.

Please see the **[Hardware Profile Guide](hardware-profile/README.md)** for step-by-step instructions on how to do any of the following:
1. **Provision GPU Nodes:** Automatically create a GPU MachineSet with the correct AWS instance types, labels, and taints.
2. **Install GPU Dashboards:** Deploy the NVIDIA DCGM Exporter dashboard directly to your OpenShift web console.
3. **Enable Time-Slicing:** Dynamically partition physical GPUs into virtual replicas so multiple workloads can share resources.
4. **Register the Hardware Profile:** The final RHOAI dashboard steps to make the GPUs selectable for deployments and workbenches.

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

---

## References

* [Upstream OpenShift AI Setup Reference](https://github.com/jharmison-redhat/openshift-setup/tree/main/charts/openshift-ai/templates)
* [RHOAI Installation Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.2/html/installing_and_uninstalling_openshift_ai_self-managed/installing-and-deploying-openshift-ai_install#requirements-for-openshift-ai-self-managed_install)

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
│       ├── gpu-operator.yaml
│       ├── infrastrcuture-operators.yaml
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
    ├── gpu-operator-installation/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    │       ├── configs/
    │       │   ├── 15-nfd-instance.yaml
    │       │   └── 25-gpu-clusterpolicy.yaml
    │       └── operators/
    │           ├── 10-nfd-operator.yaml
    │           └── 20-gpu-operator.yaml
    ├── infrastructure-utilities/
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
