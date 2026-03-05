# rhoai-argo

Deployment of Red Hat OpenShift AI (RHOAI) and its required infrastructure stack using Helm and ArgoCD.


## Getting started

To initialize RHOAI, install OpenShift GitOps if you haven't already, configure gitops permissions, and trigger the "App-of-Apps" deployment.

### 1. Check if the Openshift GitOps Subscription already exists. If not, apply it. Additionally, configure permissions for the Service Account.

```bash
oc get subscription openshift-gitops-operator -n openshift-operators || oc apply -f gitops-config/openshift-gitops-subscription.yaml

oc apply -f gitops-config/gitops-permission.yaml
```

### 2. Trigger the "App-of-Apps" deployment

### Option 1 - Default Installation (Manual Update Approval)
By default, the operators will require manual approval for any version upgrades in the OpenShift Console.

```bash
oc apply -f app-of-apps.yaml
```

### Option 2 - Install with Automatic Updates for RHOAI Dependencies (Not Automatic updates for RHOAI itself)
To allow the cluster to automatically handle future patches, besides RHOAI, without manual approval, patch the global installPlanApproval to Automatic:

```bash
oc patch application app-of-apps -n openshift-gitops --type merge -p \
'{"spec":{"source":{"helm":{"valuesObject":{"global":{"installPlanApproval":"Automatic"}}}}}}'
```

## 3. Open ArgoCD and monitor InstallPlan progress

The ArgoCD application icon is available at the top of the OpenshiftDashboard in the Waffle Menu Icon. Alternatively, retrieve the url direcrtly from the terminal.

```bash
# Get the ArgoCD URL
oc get route openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}'
```

### If you chose the Manual Installation, you will need to approve operators as they attempt to install.

- In your Openshift Dashboard, Navigate to Home > Search, type "InstallPlan" in the resource bar and select the resource type. Approve operator installations when they appear by clicking the specific InstallPlan > View InstallPlan > Approve.

- (Optional) If you would like to approve all of the currently waiting InstallPlans you can run the following command:

```bash
oc get installplan -A --no-headers | grep "false" | awk '{print $1, $2}' | xargs -L1 sh -c 'oc patch installplan $1 -n $0 --type merge -p "{\"spec\":{\"approved\":true}}"'
```

> **Note:** The ServiceMesh Operator installed by RHOAI is not the most current version, as such, the InstallPlan for the update will appear regardless of whether Manual or Automatic Approval is used. The InstallPlan can be rejected or ignored.
## Manual Steps After Sync

Some steps are cluster-specific and cannot be fully automated via GitOps:

1. **GPU MachineSet** - Create a GPU worker MachineSet for your cloud provider. See [RHOAI Installation Workshop Step 2](https://github.com/redhat-ai-americas/rhoai-installation-workshop/blob/main/docs/02-enable-gpu-support.md).

2. **Hardware Profile** - Create a Hardware Profile in the RHOAI dashboard to enable GPU assignment to workloads:
   - RHOAI Dashboard -> Settings -> Hardware profiles -> Create hardware profile
   - Add resource: `nvidia.com/gpu`, default `1`, min `1`, max `1`
   - Add toleration: operator `Exists`, effect `NoSchedule`, key `nvidia.com/gpu`
   - See [RHOAI 3.2 Hardware Profiles docs](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.2/html/working_with_accelerators/working-with-hardware-profiles_accelerators)

3. **GPU Node Taints** (optional) - Prevent non-GPU workloads from scheduling on GPU nodes. See [RHOAI Installation Workshop Step 5](https://github.com/redhat-ai-americas/rhoai-installation-workshop/blob/main/docs/05-configure-gpu-sharing-method.md).

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

## Following When Everything Gets Deployed

| Sync Wave | Summary | Resources |
|-----------|-----------|-------------|
| 0 | Namespaces | All operators |
| 5 | RHOAI Dependencies | job-set-operator, cma-operator, cert-manager, leader-worker-set, Kueue, SR-IOV, OpenTelemetry, Tempo, ClusterObservability |
| 7 | Configs | cluster-job-set, cma-controller|
| 10 | GPU Dependencies| nfd-operator |
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
│       ├── hardware-operators.yaml
│       ├── network-operators.yaml
│       ├── observability-operators.yaml
│       ├── rhoai-application.yaml
│       └── scaling-operators.yaml
└── helm/
    ├── ai-stack/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    │       ├── configs/
    │       │   ├── 07-cluster-job-set.yaml
    │       │   ├── 32-operator-deployment.yaml
    │       │   ├── 33-datasciencecluster.yaml
    │       │   ├── 35-dashboard-deployment.yaml
    │       │   └── 35-odhdashboardconfig.yaml
    │       └── operators/
    │           ├── 05-job-set.yaml
    │           ├── 05-leader-worker-set.yaml
    │           ├── 05-rhbok.yaml
    │           └── 30-rhoai-operator.yaml
    ├── dynamic-scaling/
    │   ├── Chart.yaml
    │   └── templates/
    │       ├── configs/
    │       │   └── 07-cma-controller.yaml
    │       └── operators/
    │           └── 05-cma-operator.yaml
    ├── gpu-installation/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    │       ├── configs/
    │       │   └── 25-gpu-clusterpolicy.yaml
    │       └── operators/
    │           └── 20-gpu-operator.yaml
    ├── hardware-management/
    │   ├── Chart.yaml
    │   ├── values.yaml
    │   └── templates/
    │       ├── configs/
    │       │   └── 15-nfd-instance.yaml
    │       └── operators/
    │           ├── 05-kmm.yaml
    │           └── 10-nfd-operator.yaml
    ├── network-fabric/
    │   ├── Chart.yaml
    │   └── templates/
    │       ├── configs/
    │       └── operators/
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