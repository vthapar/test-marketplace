---
description: Join cluster to Submariner broker using subctl join
---

Join a Kubernetes cluster to an existing Submariner broker using the subctl binary.

This command runs `subctl join` to connect a member cluster to the broker.

Arguments:
- cluster_install_dir: Path to the OpenShift cluster installation directory (required)
  - The directory must contain:
    - auth/kubeconfig: Kubernetes configuration file
    - metadata.json: Cluster metadata including clusterName, clusterID, infraID, and cloud provider info

Please perform the following steps:
1. Validate the cluster installation directory:
   - Check if the provided directory exists
   - Verify auth/kubeconfig file exists
   - Verify metadata.json file exists
   - Parse metadata.json to extract cluster information (clusterName, clusterID, infraID)
   - Determine the cloud provider from metadata.json (look for "aws", "gcp", "azure", or "openstack" keys)
2. Set KUBECONFIG environment variable to {cluster_install_dir}/auth/kubeconfig
3. Check if subctl is installed and available
4. Run cloud prepare for supported cloud providers:
   - Skip this step if at least one node with label submariner.io/gateway=true
   - If cloud provider is AWS, GCP, Azure, or OpenStack (detected from metadata.json):
     - Execute `subctl cloud prepare --ocp-metadata {cluster_install_dir}/metadata.json`
     - This step configures cloud-specific resources needed for Submariner
     - Verify the cloud prepare operation completed successfully
     - Track whether cloud prepare was successful (needed for step 8)
   - Ask user to label a node as gateway for other cloud providers or bare metal installations
5. Verify kubectl can connect to the cluster using the provided kubeconfig
6. Wait for gateway node to be ready:
   - Check for at least one node with label submariner.io/gateway=true
   - Use `kubectl wait --for=condition=Ready node -l submariner.io/gateway=true --timeout=300s`
   - If no gateway nodes are found or timeout occurs, inform the user that a node needs to be labeled
   - The gateway node must be Ready before proceeding with Submariner join
7. Determine broker-info.subm file location:
   - Check if broker-info.subm exists in the current working directory
   - If found, use it as the default
   - If not found, ask the user for the path to broker-info.subm file
8. Ask the user for join configuration (all parameters are optional with defaults):
   - Path to broker-info.subm file (default: ./broker-info.subm if it exists in current directory, otherwise required)
   - Cluster ID (default: clusterName from metadata.json, allow override)
   - Cable driver (default: libreswan, options: libreswan, wireguard, vxlan)
   - Service CIDR and Pod CIDR (default: auto-detect, allow override)
   - Enable globalnet (default: auto-detect from broker, allow override)
   - Any additional join flags
   - Allow user to skip all prompts and use defaults by pressing Enter
9. Execute `subctl join` with appropriate options using the configured KUBECONFIG:
   - Use the broker-info.subm file path (from step 7)
   - Use clusterName from metadata.json as cluster ID (or user override)
   - Use libreswan as cable driver (or user override)
   - Let subctl auto-detect Service CIDR and Pod CIDR (or use user overrides)
   - Auto-detect globalnet configuration (or use user override)
10. Verify the deployment and gateway status
11. Check connectivity with other joined clusters if more than one clusters are joined.

Note: You must deploy the broker first using `/deploy-broker` before joining clusters.
The cluster metadata from metadata.json can be used for cluster identification and configuration.
