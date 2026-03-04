# rhoai-argo

Deployment of Red Hat OpenShift AI (RHOAI) and its required infrastructure stack using Helm and ArgoCD.

## Overview

This repository provides a modular, "layered" approach to deploying a production-ready AI environment on OpenShift. By splitting the infrastructure into distinct layers, we ensure that hardware discovery, networking, and GPU acceleration are fully operational before the RHOAI dashboard and notebooks are deployed.

## Getting Started

To initialize the cluster and deploy all infrastructure layers, use the provided bootstrap script. This script installs the OpenShift GitOps operator, configures necessary permissions, and triggers the "App-of-Apps" deployment.

### 1. Default Installation (Manual Approval)
By default, the operators will require manual approval for any version upgrades or initial `InstallPlans` in the OpenShift Console.

```bash
./scripts/bootstrap.sh
```

### 2. Automated Installation (Optional)
To allow the cluster to automatically install operators and handle future patches (including dependencies like Service Mesh or Serverless) without manual intervention, use the `--set` flag:

```bash
./scripts/bootstrap.sh --set global.installPlanApproval=Automatic
```

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
