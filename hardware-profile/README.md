# GPU Setup & Hardware Profiles

This directory contains automation scripts and configurations for provisioning GPU nodes, enabling monitoring, and configuring GPU time-slicing for Red Hat OpenShift AI (RHOAI).

---

## ⚠️ The Hardware Scripts provision GPU resources on the cluster, skip to the final step if you already have a GPU node on your openshift cluster.

**You do not need to run these scripts if your cluster already has GPU nodes provisioned.** Depending on your environment, you may already have GPUs available. you may also not need GPUs for your AI workloads. 
* **If you already have GPU nodes:** You can skip the `add-gpu-machineset.sh` script entirely.
* **If you do not want the console GPU dashboard:** You can skip the `install-dcgm-dashboard.sh` script entirely.
* **If you are not sharing a GPU or are unfamiliar with timeslicing:** You can skip the `enable-gpu-timeslicing.sh` script entirely.

### Directory Contents
* `scripts/add-gpu-machineset.sh`: Dynamically clones an existing worker MachineSet and injects an AWS `g6e.4xlarge` instance type with the appropriate NVIDIA labels and taints.
* `scripts/install-dcgm-dashboard.sh`: Downloads and configures the NVIDIA DCGM Exporter dashboard for the OpenShift web console.
* `scripts/enable-gpu-timeslicing.sh`: Applies the ConfigMap in `configs/nvidia-gputimeslice-config.yaml` to dynamically partition physical GPUs into 8 virtual replicas, allowing for more workloads to share the same resources.

---

## 🚀 How to Run the Scripts

Ensure you are logged into your OpenShift cluster via the `oc` CLI.

**0. Make scripts executable:**
```bash
chmod +x hardware-profile/scripts/*.sh
```

**1. [OPTIONAL] Provision gpu machineset:**

```bash
./hardware-profile/scripts/add-gpu-machineset.sh
```

**2. [OPTIONAL] NVIDIA DGCM Dashboard:**

```bash
./hardware-profile/scripts/download-install-nvidia-gpu-dashboard.sh
```

**3. [OPTIONAL] Configure gpu timeslicing:**

```bash
./hardware-profile/scripts/enable-gpu-timeslice.sh
```

---

## Final Step: Creating the RHOAI Hardware Profile

Once your GPU nodes are online and the NVIDIA GPU Operator has successfully applied the drivers, you must register a Hardware Profile in the OpenShift AI dashboard. This allows users to select the GPUs when deploying models, workbenches, and other workloads.

**Perform the following steps in the RHOAI Dashboard:**

1. Navigate to **Settings** > **Environment Setup**.
2. Click on the **Hardware profiles** tab and select **Create hardware profile**.
3. Fill in the profile details (e.g., "NVIDIA L40S GPU").
4. **Add resource:** * Identifier: `nvidia.com/gpu` 
   * Default: `1` 
   * Min: `1` 
   * Max: `1`
5. **Add toleration:** * Operator: `Exists`
   * Effect: `NoSchedule`
   * Key: `nvidia.com/gpu`

*(Ref: RHOAI 3.2 Hardware Profiles)*