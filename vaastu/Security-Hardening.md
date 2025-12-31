# **🛡️ Homelab Security Hardening Strategy**

## **1\. Network Segmentation (The "Air Gap")**

*Objective: If the K8s cluster is compromised, the attacker is trapped.*

* **VLAN 10 (Home LAN):** Your family's phones, laptops.
* **VLAN 20 (Mgmt):** Only your Laptop and the Proxmox Admin UI.
* **VLAN 30 (DMZ):** The Kubernetes VMs exposed to the internet.
* **Rule:** The DMZ VLAN cannot initiate connections to VLAN 10 or 20\.
* **Implementation:** In Proxmox Firewall (Datacenter level), set a default DROP policy for outgoing traffic from DMZ VMs to 192.168.1.0/24.

## **2\. Nebula Mesh Security**

* **Groups:** Use Nebula's built-in firewall.
  * group:lighthouse \- Can only talk UDP/4242.
  * group:k8s-nodes \- Can talk TCP/6443 (API) to each other.
  * group:public-ingress \- The only group allowed to receive HTTP/80 traffic from the Lighthouse.
* **Key Management:** Store your ca.key on an encrypted USB drive or secured in 1Password. Never put it on the servers.

## **3\. Host Hardening (Proxmox & VMs)**

* **SSH:** Disable password login (PasswordAuthentication no). Use SSH keys only.
* **Fail2Ban:** Install on the Lightsail Gateway. Ban IPs after 3 failed attempts.
* **Unprivileged Containers:** If running LXC, always check "Unprivileged". This maps root inside the container to a non-root user on the host, preventing container breakout attacks.

## **4\. The "Kill Switch"**

* Configure a cron job or a simple script on the Proxmox host that can instantly shut down the "Internet Gateway" VM or stop the Nebula service if you detect an anomaly.
