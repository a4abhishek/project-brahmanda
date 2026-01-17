# **ADR 004: Security Hardening Strategy**

Date: 2026-01-03<br>
Status: Accepted

## **Context**

Project Brahmanda exposes services to the internet. We need to secure the infrastructure against external attacks and limit the blast radius if a component is compromised.

For a detailed analysis of options, see [manthana/RFC-004-Security-Hardening.md](../manthana/RFC-004-Security-Hardening.md).

## **Decision**

We will implement a **Defense-in-Depth** strategy consisting of:

1. **Network Segmentation (VLANs):**

    **VLAN Configuration:**
    - **VLAN 10 (Home) - 192.168.10.0/24:** Trusted devices (Phones, Laptops, Personal computers).
    - **VLAN 20 (Mgmt) - 192.168.20.0/24:** Admin access (Proxmox UI at .200, SSH, IPMI).
    - **VLAN 30 (DMZ) - 192.168.30.0/24:** Exposed workloads (K8s VMs, Reverse Proxy).

    **Firewall Rules (Router/Firewall Level):**

    ```
    # Inter-VLAN Policy
    Home (VLAN 10) -> Mgmt (VLAN 20): ALLOW (admin needs to manage Proxmox)
    Home (VLAN 10) -> DMZ (VLAN 30): DENY (no direct access to cluster)
    Mgmt (VLAN 20) -> DMZ (VLAN 30): ALLOW (management needs to access K8s nodes)
    DMZ (VLAN 30) -> Home (VLAN 10): DENY (compromised workload cannot pivot to home)
    DMZ (VLAN 30) -> Mgmt (VLAN 20): DENY (compromised workload cannot access Proxmox)
    DMZ (VLAN 30) -> Internet: ALLOW (K8s needs to pull images)
    ```

    **Implementation:**
    - Configure VLAN tagging on managed switch.
    - Set Proxmox bridge (vmbr0) to trunk mode.
    - Assign VM network interfaces to specific VLANs via Proxmox UI or Terraform.

    **Example (Terraform - Proxmox VM):**

    ```hcl
    resource "proxmox_vm_qemu" "k8s_worker" {
      name = "k8s-worker-01"
      network {
        bridge = "vmbr0"
        tag    = 30  # DMZ VLAN
      }
    }
    ```

2. **Nebula Mesh Security & Traffic Flow:**

    - **Split-Horizon Strategy:**
        - **Intra-Cluster (East-West):** All node-to-node traffic (Etcd, Longhorn, Pods) MUST use the **Local LAN (VLAN 30)**. We avoid Nebula for internal traffic to prevent encryption overhead and latency.
        - **Ingress (North-South):** Nebula is used strictly for secure external access (Lighthouse -> Cluster).
    - **Firewall Rules:**
        - `group:lighthouse`: UDP/4242 only.
        - `group:public-ingress`: Only group allowed to accept inbound HTTP/80 and HTTPS/443 from Lighthouse.

3. **Host Hardening (Ansible):**

    - **Fail2Ban:** Install on Kshitiz (Gateway) to ban IPs after 3 failed attempts.
    - **Unprivileged Containers:** LXC containers must map root to a non-root user.

   #### **SSH Daemon Hardening Policy**

    The SSH daemon (`sshd`) on all provisioned hosts **MUST** be hardened. The following policies are enforced via Ansible:

    - **Authentication:**
        - `PubkeyAuthentication yes`: Only public key authentication is permitted.
        - `PasswordAuthentication no`: Disables password-based logins, mitigating brute-force attacks.
        - `KbdInteractiveAuthentication no`: Disables challenge-response authentication.
        - `UsePAM no`: Disables Pluggable Authentication Modules to simplify the auth chain and reduce attack surface.
    - **Authorization & Privileges:**
        - `PermitRootLogin no`: Disables direct root login.
        - `Default User Convention`: We will adhere to the standard user provided by the cloud image (e.g., `ubuntu`). The security gain from changing default usernames is minimal compared to strong authentication.
    - **Session & Connection Management:**
        - `MaxAuthTries 2`: Reduces exposure to brute-force attempts.
        - `AllowAgentForwarding no`: Prevents socket hijacking on compromised bastion/jump hosts.
        - `X11Forwarding no`: Disables GUI forwarding on headless servers.
    - **Security by Obscurity:**
        - A non-standard SSH port (e.g., `22022`) is used to avoid automated bot scans. This is not a primary security control but a practical measure to reduce noise.

    <details>
    <summary>Original SSHD Config `/etc/ssh/sshd_config`</summary>

    ```bash
    # This is the sshd server system-wide configuration file.  See
    # sshd_config(5) for more information.
    
    # This sshd was compiled with PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games
    
    # The strategy used for options in the default sshd_config shipped with
    # OpenSSH is to specify options with their default value where
    # possible, but leave them commented.  Uncommented options override the
    # default value.
    
    Include /etc/ssh/sshd_config.d/*.conf
    
    # When systemd socket activation is used (the default), the socket
    # configuration must be re-generated after changing Port, AddressFamily, or
    # ListenAddress.
    #
    # For changes to take effect, run:
    #
    #   systemctl daemon-reload
    #   systemctl restart ssh.socket
    #
    #Port 22
    #AddressFamily any
    #ListenAddress 0.0.0.0
    #ListenAddress ::
    
    #HostKey /etc/ssh/ssh_host_rsa_key
    #HostKey /etc/ssh/ssh_host_ecdsa_key
    #HostKey /etc/ssh/ssh_host_ed25519_key
    
    # Ciphers and keying
    #RekeyLimit default none
    
    # Logging
    #SyslogFacility AUTH
    #LogLevel INFO
    
    # Authentication:
    
    #LoginGraceTime 2m
    #PermitRootLogin prohibit-password
    #StrictModes yes
    #MaxAuthTries 6
    #MaxSessions 10
    
    #PubkeyAuthentication yes
    
    # Expect .ssh/authorized_keys2 to be disregarded by default in future.
    #AuthorizedKeysFile     .ssh/authorized_keys .ssh/authorized_keys2
    
    #AuthorizedPrincipalsFile none
    
    #AuthorizedKeysCommand none
    #AuthorizedKeysCommandUser nobody
    
    # For this to work you will also need host keys in /etc/ssh/ssh_known_hosts
    #HostbasedAuthentication no
    # Change to yes if you don't trust ~/.ssh/known_hosts for
    # HostbasedAuthentication
    #IgnoreUserKnownHosts no
    # Don't read the user's ~/.rhosts and ~/.shosts files
    #IgnoreRhosts yes
    
    # To disable tunneled clear text passwords, change to no here!
    #PasswordAuthentication yes
    #PermitEmptyPasswords no
    
    # Change to yes to enable challenge-response passwords (beware issues with
    # some PAM modules and threads)
    KbdInteractiveAuthentication no
    
    # Kerberos options
    #KerberosAuthentication no
    #KerberosOrLocalPasswd yes
    #KerberosTicketCleanup yes
    #KerberosGetAFSToken no
    
    # GSSAPI options
    #GSSAPIAuthentication no
    #GSSAPICleanupCredentials yes
    #GSSAPIStrictAcceptorCheck yes
    #GSSAPIKeyExchange no
    
    # Set this to 'yes' to enable PAM authentication, account processing,
    # and session processing. If this is enabled, PAM authentication will
    # be allowed through the KbdInteractiveAuthentication and
    # PasswordAuthentication.  Depending on your PAM configuration,
    # PAM authentication via KbdInteractiveAuthentication may bypass
    # the setting of "PermitRootLogin prohibit-password".
    # If you just want the PAM account and session checks to run without
    # PAM authentication, then enable this but set PasswordAuthentication
    # and KbdInteractiveAuthentication to 'no'.
    UsePAM yes
    
    #AllowAgentForwarding yes
    #AllowTcpForwarding yes
    #GatewayPorts no
    X11Forwarding yes
    #X11DisplayOffset 10
    #X11UseLocalhost yes
    #PermitTTY yes
    PrintMotd no
    #PrintLastLog yes
    #TCPKeepAlive yes
    #PermitUserEnvironment no
    #Compression delayed
    #ClientAliveInterval 0
    #ClientAliveCountMax 3
    #UseDNS no
    #PidFile /run/sshd.pid
    #MaxStartups 10:30:100
    #PermitTunnel no
    #ChrootDirectory none
    #VersionAddendum none
    
    # no default banner path
    #Banner none
    
    # Allow client to pass locale environment variables
    AcceptEnv LANG LC_*
    
    # override default of no subsystems
    Subsystem       sftp    /usr/lib/openssh/sftp-server
    
    # Example of overriding settings on a per-user basis
    #Match User anoncvs
    #       X11Forwarding no
    #       AllowTcpForwarding no
    #       PermitTTY no
    #       ForceCommand cvs server
    
    TrustedUserCAKeys /etc/ssh/lightsail_instance_ca.pub
    ```

    </details>

4. **Emergency Kill Switch (Layered Defense):**
    - **Level 1 (Software):** A local script on the host to stop networking, which is also triggerred by a **GitHub Action** that destroys the Lighthouse (Kshitiz) to instantly sever public internet access.
    - **Level 2 (Remote Hardware):** A **16A Smart Plug** connects the NUC to the wall. Allows for a remote "Hard Kill" if the OS is compromised or frozen.
    - **Level 3 (Physical):** The **Physical Wall Switch** serves as the ultimate, unhackable fail-safe requiring physical presence.

## **Consequences**

- **Positive:**
  - Compromise of a K8s node does not grant access to the home network.
  - Identity-based networking (Nebula) prevents unauthorized devices from joining the mesh even if they have the IP.
- **Negative:**
  - Increased network complexity (VLAN management).
  - Requires a router/switch capable of VLAN tagging.
