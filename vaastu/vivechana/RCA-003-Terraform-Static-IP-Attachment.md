# RCA-003: Terraform Lightsail Static IP Detachment

**Date:** January 10, 2026
**Status:** Resolved
**Components:** Terraform, AWS Lightsail
**Impact:** Loss of static IP connectivity after instance recreation.

## 1. Problem Description
After modifying the Terraform configuration to inject a specific SSH key pair, the AWS Lightsail instance (`kshitiz-lighthouse`) was successfully destroyed and recreated. However, the previously allocated Static IP (`13.214.253.51`) was not re-attached to the new instance. The new instance instead received a temporary dynamic public IP (e.g., `47.xxx.xxx.xxx`), breaking SSH access and downstream configurations (Ansible inventory).

## 2. Root Cause Analysis
The issue stems from how Terraform calculates dependencies for the `aws_lightsail_static_ip_attachment` resource versus how AWS handles instance destruction.

1.  **Dependency on Name, Not ID:** The `aws_lightsail_static_ip_attachment` resource requires the `instance_name` argument.
    ```hcl
    resource "aws_lightsail_static_ip_attachment" "example" {
      instance_name = aws_lightsail_instance.kshitiz.name
      # ...
    }
    ```
2.  **Immutable Name:** When the instance was recreated (to change the Key Pair), the **name** of the instance (`kshitiz-lighthouse`) remained identical.
3.  **State Logic Flaw:** Terraform compared the desired state (name=`kshitiz-lighthouse`) with the recorded state. Since the name string did not change, Terraform determined that the `attachment` resource required no changes.
4.  **Implicit Deletion:** In AWS, when a Lightsail instance is terminated, any attached Static IP is automatically detached. Terraform's state file did not reflect this side effect; it still believed the IP was attached because it "owned" the attachment resource and hadn't been told to destroy it.

## 3. Solution
To force Terraform to recognize the dependency on the *physical* instance lifecycle rather than just its logical name, we used the `replace_triggered_by` lifecycle argument.

**Code Change in `main.tf`:**

```hcl
resource "aws_lightsail_static_ip_attachment" "kshitiz_attach" {
  static_ip_name = aws_lightsail_static_ip.kshitiz.name
  instance_name  = aws_lightsail_instance.kshitiz.name

  # FIX: Force replacement of the attachment if the instance is replaced
  lifecycle {
    replace_triggered_by = [aws_lightsail_instance.kshitiz]
  }
}
```

This directive instructs Terraform to treat the Attachment as "stale" whenever the Instance resource is replaced, forcing it to re-run the attachment logic against the AWS API.

## 4. Verification
After applying the fix:
1.  Running `terraform apply` detected the missing attachment (or forced a new one).
2.  The Static IP (`13.214.253.51`) was correctly associated with the new instance.
3.  SSH connectivity and Ansible operations resumed successfully using the stable IP.
