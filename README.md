# Azure Silo Cluster 

## 1. Project Overview
This repository contains the Terraform infrastructure as code (IaC) to provision a distributed, S3-compatible object storage cluster on Microsoft Azure. The deployment utilizes Silo (a MinIO fork) configured for erasure-coded storage across multiple nodes. The primary objective is to deploy a predictable, state-managed storage architecture strictly within a 6-vCPU resource boundary while enforcing private network isolation.

## 2. Architecture


## 3. Technology Stack
Infrastructure Provisioning: Terraform

Cloud Provider: Microsoft Azure

Compute: Ubuntu 24.04 LTS

Storage Engine: Silo (Docker containerized)

Filesystem: XFS via Azure Managed Disks

Networking: Azure Virtual Networks, Network Security Groups (NSGs)

## 4. Infrastructure Design
The environment is geographically located in the spaincentral region and split into compute and storage layers:

Access Layer (Bastion): A single public-facing VM handles all inbound SSH traffic.

Storage Layer: Two Standard_E2ds_v4 instances operate strictly on a private subnet.

Network Stability: Static private IP allocations (10.0.2.5 and 10.0.2.4) are enforced at the Azure NIC level via Terraform to prevent quorum-breaking IP drift upon hardware deallocation.

## 5. Storage Architecture
The backend relies on four 10GB Azure Managed Disks (two attached to each node via LUN 10 and 11).

Disks are formatted with XFS and persistently mounted via UUID in /etc/fstab to /data/disk1 and /data/disk2.

Silo operates in a distributed erasure-coded configuration utilizing all four drives.

Note: Erasure coding provides data parity, but failure tolerance is strictly bound to the 2-node quorum limit. Total node loss will require disaster recovery procedures.

## 6. Security and Access
The storage nodes have no public IP addresses and are isolated from the public internet.

Network Security Groups (NSGs): Block external access to the Silo API (port 9000) and Console (port 9001).

Administrative Access: Achieved exclusively via SSH tunneling through the Bastion host, forwarding the local port to the private node's loopback interface.

Authentication: Disabled password authentication on all VMs; access relies on ED25519 SSH keys.

## 7. Repository Structure
```
├── provider.tf      # Azure provider and backend configuration
├── network.tf       # vNet, subnets, and NSG rules
├── bastion.tf       # Bastion VM and public IP configuration
├── cluster.tf       # Storage nodes, NICs (Static IP), and Managed Disks
├── bootstrap.sh     # VM cloud-init/custom_data payload
├── start-cluster.sh # Docker run execution script for Silo
└── README.md        # Project documentation
```
## 8. Deployment Guide
Prerequisites:

Azure CLI installed and authenticated.

Terraform installed.

An existing ED25519 SSH key pair.

## Execution:
### 1.Initialize the Terraform backend:
```
terraform init
```
### 2.Review the infrastructure plan:

```Bash
terraform plan
```

### 3.Apply the configuration:

```Bash
terraform apply
```

### 4.Access the Bastion to format and mount the data disks via XFS.

### 5.Execute the container startup script (start-cluster.sh) on both nodes to establish the quorum.

## 9. Verification and Operational Checks
To verify the cluster health internally on a node:

```Bash
curl -I [http://127.0.0.1:9001](http://127.0.0.1:9001)
```
Expected Output: HTTP/1.1 200 OK

To access the dashboard locally, establish an SSH tunnel:

```Bash
ssh -o ServerAliveInterval=60 -J acumenadmin@<BASTION_IP> -L 8081:127.0.0.1:9001 acumenadmin@10.0.2.5
```
Navigate to http://127.0.0.1:8081 in a local browser to view the active storage quorum.

## 10. Cost Considerations
This architecture was designed to fit within a strict 6-vCPU footprint. To optimize costs:

- Compute resources can be deallocated when not in use (static private IPs ensure the cluster survives reboots).

- Terraform state tracks disks to ensure no orphaned Managed Disks generate background costs after destruction.

## 11. Cleanup and Teardown
To completely destroy the environment and halt all billing:

```Bash
terraform destroy
```
Warning: This is a destructive action that will permanently delete the VNet, Bastion, Cluster VMs, and all data stored on the Managed Disks.

## 12. Limitations and Future Improvements
Credential Management: The Silo root credentials are currently passed as plaintext environment variables in the deployment script. Future iterations should transition this to a secured .env file (chmod 600) or Azure Key Vault integration.

Load Balancing: The architecture currently relies on a direct SSH tunnel to node-1 for administrative dashboard access. An internal Azure Load Balancer could be implemented to distribute API traffic across both nodes.

Automated Disk Provisioning: XFS formatting and UUID mounting are currently manual post-deployment steps. This logic should be migrated into the Terraform custom_data or an Ansible playbook.

