# RFC-009: Vyom (Compute Layer) Provisioning Strategy

**Status:** Proposed<br>
**Date:** 2026-01-18

## 1. Context

With the Kshitiz (Edge) layer automated, the next logical step is to programmatically provision the Vyom (Compute) layer, which will host the K3s Kubernetes cluster on the on-premise Proxmox server. This requires a robust, repeatable, and fast method for creating virtual machines.

This RFC outlines the definitive strategy for creating these VMs, including the choice of base image, hardware allocation, and the technical implementation details within Terraform.

## 2. Problem Statement

We need to select a VM provisioning strategy that meets the following criteria:

1. **Speed:** The creation of the 3-node cluster should be fast to encourage iterative development and rapid recovery.
2. **Consistency:** Every VM created must be an identical, clean slate, free from manual configuration drift.
3. **Automation:** The process must be fully automatable via Terraform, with no manual steps required in the Proxmox UI during a `terraform apply`.
4. **Flexibility:** The strategy must allow for defining distinct hardware resources (CPU, RAM, Storage) for different VM roles (e.g., control-plane vs. worker) at creation time.

## 3. Alternatives Considered

### Option A: ISO-Based Installation (Rejected)

- **Method:** Terraform creates a new VM, attaches a Linux distro ISO (like Ubuntu or Debian), and relies on cloud-init or a similar mechanism to run a full, unattended OS installation.
- **Pros:**
  - Conceptually simple, mirroring a manual installation.
- **Cons:**
  - **Extremely Slow:** A full OS installation for each VM can take 10-15 minutes, leading to a 30+ minute cluster creation time. This violates the principle of rapid iteration.
  - **High I/O:** Places significant I/O strain on the Proxmox host during installation.
  - **Brittle:** Dependent on the specific unattended installation mechanism of the chosen distro, which can change.
- **Verdict:** Rejected due to poor performance and a process that is more complex than necessary.

### Option B: Proxmox Template Cloning (Accepted)

- **Method:** A one-time manual process is used to create a "golden image" VM template in Proxmox, which is pre-configured for cloud-init. Terraform then uses the highly optimized Proxmox "clone" feature to stamp out new VMs from this template nearly instantaneously.
- **Pros:**
  - **Extremely Fast:** Cloning an existing VM disk is significantly faster than a full OS installation. Cluster creation time drops from 30+ minutes to under 2 minutes.
  - **Guaranteed Consistency:** Every VM is a perfect byte-for-byte copy of the trusted template.
  - **Decouples OS Image from Provisioning:** The OS image can be updated and a new template created independently of the Terraform code.
  - **Resource Override:** As detailed below, Terraform can override the template's default resources (CPU, RAM, disk size) during the clone operation, providing full flexibility.
- **Verdict:** **Accepted.** This is the industry-standard best practice for VM automation in a Proxmox environment and perfectly aligns with our goals of speed and consistency.

## 4. Proposal: The Template-Cloning Strategy

We will adopt the **Proxmox Template Cloning** strategy.

### 4.1. VM Resource Allocation

The resource plan is borrowed directly from [RFC-001](./RFC-001-Homelab-Architecture.md), which is based on the available **48GB RAM** of the Proxmox host.

| Node Role         | # of VMs | vCPUs | RAM   | Storage |
| :---------------- | :------- | :---- | :---- | :------ |
| **Control-Plane** | 1        | 4     | 8 GB  | 64 GB   |
| **Worker Node**   | 2        | 4     | 16 GB | 128 GB  |
| **Total**         | **3 VMs**  | **12**  | **40 GB** | **320 GB**|

### 4.2. Guest Operating System: Ubuntu 24.04 LTS

While Debian is a solid choice, **Ubuntu 24.04 LTS (Noble Numbat)** is selected for the following reasons:

- **Consistency:** The Kshitiz (Edge) node already runs Ubuntu 24.04. Using the same OS across the entire stack reduces cognitive load and ensures tooling compatibility (e.g., package names, file paths).
- **Cloud-Image Availability:** Canonical provides official, cloud-init-ready Ubuntu images in various formats (including `.qcow2`), and the `.img` format we will use is easy to import into Proxmox.
- **Broad Support:** K3s, Kubernetes, and the wider ecosystem have first-class support and extensive documentation for Ubuntu.

### 4.3. Disk Controller: SCSI with VirtIO SCSI Controller

When defining the VM hardware in Terraform, we will use the `scsi` disk type with a `virtio-scsi-single` controller.

- **Method:**

    ```hcl
    resource "proxmox_vm_qemu" "k3s_server" {
      scsihw = "virtio-scsi-single" // Set the controller type

      disk {
        type    = "scsi"
        storage = "local-lvm"
        size    = "64G"
        //...
      }
    }
    ```

- **Why `scsi` over `virtio` block?**
  - **Flexibility:** The VirtIO SCSI controller allows for easier hot-plugging of disks in the future.
  - **Performance:** It provides near-native disk performance, on par with VirtIO Block for most workloads.
  - **Advanced Features:** It is better suited for advanced storage operations and is the recommended default for modern Linux VMs in Proxmox.

#### **Interaction with In-Guest Storage (Longhorn)**

A critical consideration is how the hypervisor's disk controller interacts with the distributed storage solution, Longhorn, that will run inside the Kubernetes cluster.

- **Separation of Layers:** The `VirtIO SCSI` controller operates at the hypervisor layer (L1), presenting a simple, high-performance block device (e.g., `/dev/sda`) to the guest operating system. Longhorn operates entirely within the guest OSs (L2), using the provided block device's filesystem to manage its storage pool.
- **No Replication Conflict:** We will **not** be using any of Proxmox's storage replication features (like ZFS replication) for the VM disks. The `local-lvm` storage is local to the Proxmox host. All data replication for persistent volumes will be handled exclusively by Longhorn, which will manage its replicas across the different worker nodes over the network.
- **Conclusion:** This creates a clean separation of responsibility. Proxmox provides a fast, simple disk, and Longhorn manages the complexity of distributed, replicated storage on top of it without conflict.

### 4.4. CI/CD Orchestration: The "Management Outpost" Pattern

An earlier proposal suggested using the `Kshitiz` node as a CI/CD jump host. This was identified as a flawed strategy, as it creates a circular dependency: the CI/CD pipeline would rely on infrastructure that it is also responsible for managing.

Through the churning (`manthana`) process, we conceptualized a superior architecture and have named it the **"Management Outpost" pattern**. This pattern provides a dedicated, out-of-band orchestration point that is decoupled from the infrastructure it manages.

While the full, detailed strategy for this new architectural plane will be defined in  a separate RFC for Brahmaloka-Orchestration-Plane-Strategy, the core principle is that a dedicated runner on the local network will be responsible for executing the `terraform apply` for the Vyom cluster. This completely resolves the circular dependency issue and is the accepted path forward.

### 4.5. Prerequisite: Template Creation (Prakriti)

Adopting the cloning strategy requires a "golden image" template named **Prakriti** (Primal Matter) to exist in Proxmox. The creation of this template is a one-time manual task that involves securely injecting a master SSH key for emergency access. The following steps, which will be documented in `vaastu/001-Sarga.md`, outline the definitive procedure.

> In our cosmology, the Creator (`Brahma`) from within the Realm of Creation (`Brahmaloka`) uses the Cycle (`Samsara`) to mold the Primal Matter (`Prakriti`) into the Physical Realm (`Vyom`).

**1. Generate and Secure a Dedicated Master Key:**

- A dedicated SSH key pair (`prakriti-master-key`) is generated locally.
- The private key is stored securely in 1Password as `"Prakriti Master Key"`. This key provides "break-glass" access to all nodes cloned from the template.
- The public key is temporarily copied to the Proxmox host (e.g., at `/tmp/id_prakriti.pub`).

**2. Create and Configure the Template VM:**

- A temporary VM is created with the name `prakriti-template` and minimal resources.

     ```bash
     qm create 9000 --name 'prakriti-template' --memory 1024 --cores 1 --net0 virtio,bridge=vmbr0
     ```

- The downloaded cloud image is imported into the VM's storage.
- **Crucially, a temporary static IP and the master SSH key are injected via `qm set` commands:**

     ```bash
     qm set 9000 --ipconfig0 ip=192.168.68.201/20,gw=192.168.68.1
     qm set 9000 --sshkeys /tmp/id_prakriti.pub
     ```

**3. Install Guest Agent:**

- The temporary VM is started (`qm start 9000`).
- The operator SSHes into the VM using the temporary static IP and the local `prakriti-master-key` private key.
- The `qemu-guest-agent` is installed via `apt-get`.
- The VM is cleanly shut down.

**4. Finalize and Clean Up:**

- The temporary SSH public key is deleted from the Proxmox host's `/tmp` directory.
- The temporary static IP configuration is reset to DHCP on the VM definition (`qm set 9000 --ipconfig0 ip=dhcp`).
- The VM is converted to a read-only template (`qm template 9000`).
- The temporary local key pair files are securely deleted.

This process results in a secure, production-grade `prakriti-template` ready for automated cloning.

## 5. Impact

- A new, **one-time manual step** will be added to `vaastu/001-Sarga.md`. This step will detail how to download the Ubuntu cloud image and create the Proxmox template. This is a prerequisite before the `vyom` Terraform code can be run.
- The `samsara/terraform/vyom` module will be implemented using `proxmox_vm_qemu` resources that `clone` this template.
- The `samsara/terraform/vyom/variables.tf` file will be updated to reference a template name instead of an ISO path.

## 6. Conclusion

The Template-Cloning strategy provides a fast, consistent, and scalable foundation for the Vyom compute layer. It aligns with industry best practices for VM automation. When combined with the "Management Outpost" orchestration strategy detailed in RFC-010, it creates a fully automatable and robust system for managing the entire lifecycle of the on-premise cluster.
