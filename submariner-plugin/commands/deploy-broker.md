---
description: Deploy Submariner broker to the cluster
---

Deploy the Submariner broker component to a Kubernetes cluster using subctl.

The broker acts as the central coordination point for Submariner connections between clusters.

Arguments:
- cluster_install_dir: Path to the OpenShift cluster installation directory (required)
  - The directory must contain:
    - auth/kubeconfig: Kubernetes configuration file

Please perform the following steps:
1. Validate the cluster installation directory:
   - Check if the provided directory exists
   - Verify auth/kubeconfig file exists
2. Set KUBECONFIG environment variable to {cluster_install_dir}/auth/kubeconfig
3. Check if subctl is installed and available
4. Verify kubectl can connect to the cluster using the provided kubeconfig
5. Ask the user for broker configuration options:
   - Globalnet CIDR (if needed for overlapping Pod/Service CIDRs)
   - Default GlobalNet cluster size
   - Any additional broker flags
6. Execute `subctl deploy-broker` with appropriate options using the configured KUBECONFIG
7. Save the broker-info.subm file location for joining clusters
8. Verify the broker deployment status
9. Display the broker information needed for joining member clusters

Important notes:
- Only one broker is needed per Submariner deployment
- The broker should typically be deployed to a stable, central cluster
- Save the broker-info.subm file securely as it's needed to join other clusters
