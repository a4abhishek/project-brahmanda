# RCA-008: Brahmaloka "Connection Refused" Cascade

**Date:** 2026-01-30<br>
**Component:** Brahmaloka (Orchestration Plane)<br>
**Status:** Resolved

## 1. Summary

During the provisioning of the `Brahmaloka` runner VM, automation failed repeatedly with a cascade of misleading errors ranging from "Connection reset" to "No space left on device" and finally "Connection refused". The root cause was a combination of **Resource Exhaustion** (RAM/Disk) masking a fundamental **IP Address Conflict**.

## 2. Timeline of Events

1. **Initial Failure ("Connection reset"):**
    * Terraform successfully provisioned the VM at `192.168.68.250`.
    * Ansible failed immediately with `Connection reset by 192.168.68.250`.
    * *Hypothesis:* Cloud-Init race condition or SSH key injection failure.
    * *Action:* Retried with debug flags.

2. **Secondary Failure ("No space left on device"):**
    * After manual intervention, Ansible connected but failed during `apt install`.
    * *Diagnosis:* The 64GB virtual disk was not resized by the Guest OS; root partition remained at 2GB (template size).
      <br> *Please refer to [RCA-009](./RCA-009-Virtual-Disk-Provisioning-Mismatch.md) for more details.*
    * *Action:* Added `growpart` task to Ansible playbook.

3. **Tertiary Failure ("OOM Kill"):**
    * The VM became unresponsive after ~10 hours.
    * *Diagnosis:* Total VM RAM allocation (48GB) equaled Host Physical RAM (48GB). Proxmox OOM killer terminated the VM process.
    * *Action:* Rightsized VMs (Brahmaloka: 8GB -> 4GB, Vyom: 32GB -> 24GB).

4. **Final Failure ("Connection refused"):**
    * After resizing and recreating the VM, Ansible failed again with `Connection refused` (Port 22 closed).
    * *Investigation:* SSH via Proxmox Host confirmed the VM was running, but `ssh.service` was dead.
    * *Critical Test:* Pinging `192.168.68.250` while the VM was **destroyed** returned success.
    * *Root Cause:* A rogue device on the network had claimed `.250`.

## 3. Root Cause

**Primary Cause (The Mask):**
An **IP Address Conflict** at `192.168.68.250`.

* When the VM was up, traffic flapped between the VM and the rogue device.
* The rogue device responded to Ping but rejected SSH (Port 22 closed), causing "Connection refused".

**Contributing Factors (The Confusion):**

1. **Resource Exhaustion:** Real OOM and Disk Space issues on the VM created genuine failures that distracted from the network issue.
2. **Cloud-Init Complexity:** We assumed "Connection refused" meant Cloud-Init failed to configure SSH keys, leading us to refactor the entire boot process (removing Terraform key injection) unnecessarily (though the new design is more robust).

## 4. Resolution

1. **IP Migration:** Changed Brahmaloka static IP to `192.168.68.240` (Verified free via Ping).
2. **Resource Rightsizing:** Reduced total VM memory allocation to leave 16GB headroom for Proxmox.
3. **Boot Strategy:** Standardized on the "Vyom Strategy" — boot with baked-in Prakriti Key, then swap keys via Ansible.

## 5. Learnings (Nidaan)

* **Network Truth:** Never assume an IP is free because it *should* be. Always `ping` before provisioning a static IP.
* **The "Connection Refused" Rule:** If SSH says "Connection refused", it means **host is up** but **port is down**. If you just created the VM, verify you are talking to the *correct* host.
* **Physical Limits:** Infrastructure as Code cannot defy physics. Always calculate total RAM commitment against physical hardware before defining variables.

## 6. Action Items

* [x] Update `samsara/terraform/brahmaloka/locals.tf` to use IP `.240`.
* [x] Document `.250` as a "Forbidden IP" in network documentation.
* [x] Commit the resource-optimized Terraform configuration.

## 7. Forensic Identification of Rogue Device

To identify the device holding `192.168.68.250`, we performed an ARP lookup and Nmap scan from the Proxmox host.

**1. MAC Identification:**

```bash
root@proxmox:~# ip neigh show 192.168.68.250
192.168.68.250 dev vmbr0 lladdr f0:09:0d:xx:xx:xx REACHABLE
```

**2. Service Discovery (Nmap):**

```bash
root@proxmox:~# nmap -A 192.168.68.250
PORT    STATE SERVICE  VERSION
80/tcp  open  http     OpenWrt uHTTPd
443/tcp open  ssl/http OpenWrt uHTTPd
| ssl-cert: Subject: commonName=tplinkdeco.net/countryName=CN
MAC Address: F0:09:0D:XX:XX:XX (Unknown)
Device type: WAP
Running: Linux 3.X|4.X
OS details: OpenWrt Chaos Calmer 15.05 ...
```

**Conclusion:** The "rogue" device was a **TP-Link Deco Mesh Satellite Node**. These infrastructure devices often assign themselves secondary or backhaul IPs that do not appear in the standard "Client List" of the router's mobile app, leading to the false assumption that the IP was free.

**Learning:** Network infrastructure (Routers, APs, Switches) are silent residents of the subnet. Always trust `ping` and `nmap` over the router's own "Attached Devices" UI.

## 8. Prevention & Faster Debugging

**How could we have prevented this?**

1. **Pre-Flight Checks:** Automation scripts (Makefile) should attempt to `ping` the target static IP before provisioning. If it responds, the script should abort immediately ("Error: IP Occupied").
2. **IPAM (IP Address Management):** Maintain a simple table of assigned IPs in the documentation (`001-Sarga.md`) to avoid "guessing" free slots.

**How could we have debugged faster?**

1. **The "Scream Test":** When connectivity is weird, **Stop the VM**. If the IP is still pingable, you have a conflict. We did this last; we should have done it first.
2. **Avoid the Complexity Trap:** We assumed the failure was due to complex reasons (Cloud-Init race conditions, Key encoding, Terraform state) because we were working with complex tools. We ignored the simple literal error: "Connection Refused" means "Host is Up".
3. **Trust Standard Errors:** `Connection refused` (Port Closed) is fundamentally different from `Connection timeout` (Host Down) or `Permission denied` (Auth Fail). Trusting the exact error text would have ruled out "Auth Fail" immediately.
