# Submariner Plugin for Claude Code

A Claude Code plugin that integrates Submariner's `subctl` CLI to help manage multi-cluster Kubernetes connectivity.

## Overview

This plugin provides slash commands for common Submariner operations, making it easier to deploy, manage, diagnose, and troubleshoot Submariner connections between Kubernetes clusters.

## Prerequisites

- Claude Code installed and configured
- `subctl` binary installed and available in your PATH
- `kubectl` configured with access to your Kubernetes clusters
- Active Kubernetes cluster contexts

## Installation

Install the plugin locally:

```bash
claude plugins install ./submariner-plugin
```

Or if publishing to a registry:

```bash
claude plugins install submariner
```

## Available Commands

The plugin provides the following slash commands:

### `/deploy-broker`
Deploy the Submariner broker to your Kubernetes cluster. The broker acts as the central coordination point for all cluster connections.

**Usage:**
```
/deploy-broker
```

### `/deploy`
Join a cluster to an existing Submariner broker using `subctl join`. Use this after deploying the broker to connect member clusters.

**Usage:**
```
/deploy
```

### `/show-status`
Display comprehensive status of Submariner components and connections including gateway nodes, cable connections, and service discovery.

**Usage:**
```
/show-status
```

### `/diagnose`
Run comprehensive diagnostics to identify connectivity issues, CNI compatibility, firewall configuration, and gateway health.

**Usage:**
```
/diagnose
```

### `/verify`
Verify end-to-end connectivity between Submariner-connected clusters including pod-to-pod and service discovery.

**Usage:**
```
/verify
```

### `/uninstall`
Safely remove Submariner components from the cluster.

**Usage:**
```
/uninstall
```

### `/troubleshoot-health`
**[ENTRY POINT]** Comprehensive health check that assesses Submariner deployment and recommends the next troubleshooting step. This is where you should start when diagnosing issues.

**Usage:**
```
/troubleshoot-health <kubeconfig>
```

**What it checks:**
- Pod status
- Tunnel connectivity
- Gateway logs
- ESP/Firewall detection
- Submariner diagnostics

### `/troubleshoot-tunnel`
Troubleshoot why inter-cluster tunnels are not in 'connected' status. Analyzes gateway logs, cable drivers, and IP selection to identify root cause.

**Usage:**
```
/troubleshoot-tunnel <kubeconfig1> <kubeconfig2>
```

**Diagnoses:**
- ESP firewall blocking
- UDP port blocking
- IPSec authentication issues
- Network connectivity problems

### `/troubleshoot-esp-check`
Test and fix ESP protocol (IP 50) firewall blocking by applying UDP encapsulation. Supports both ACM and subctl deployments.

**Usage:**
```
/troubleshoot-esp-check <kubeconfig1> <kubeconfig2>
```

**What it does:**
- Applies forceUDPEncaps configuration
- Restarts gateway pods
- Verifies tunnel connectivity
- Confirms if ESP blocking was the issue

### `/troubleshoot-datapath-check`
Verify end-to-end datapath connectivity between clusters including pod-to-pod and service connectivity.

**Usage:**
```
/troubleshoot-datapath-check <kubeconfig1> <kubeconfig2>
```

**What it tests:**
- Pod-to-pod connectivity
- Service connectivity
- DNS resolution

### `/troubleshoot-mtu-check`
Diagnose MTU/fragmentation issues by testing connectivity with different packet sizes.

**Usage:**
```
/troubleshoot-mtu-check <kubeconfig1> <kubeconfig2>
```

**What it does:**
- Tests with default packet size (~3000 bytes)
- Tests with small packet size (300 bytes)
- Recommends TCP MSS clamping if MTU issue detected

## Offline Diagnostics

The plugin includes comprehensive offline diagnostic capabilities for analyzing Submariner deployments without live cluster access.

### Data Collection Script

**`submariner-collect-full-diagnostics.sh`**

A comprehensive script to collect all necessary diagnostic data from Submariner deployments.

**Location:** `submariner-plugin/scripts/submariner-collect-full-diagnostics.sh`

**Usage:**
```bash
# Single cluster diagnostics
./submariner-collect-full-diagnostics.sh /path/to/kubeconfig1

# Multi-cluster diagnostics without verification tests
./submariner-collect-full-diagnostics.sh /path/to/kubeconfig1 /path/to/kubeconfig2

# Full diagnostics with verification tests (recommended)
./submariner-collect-full-diagnostics.sh /path/to/kubeconfig1 /path/to/kubeconfig2 cluster1 cluster2

# With complaint description
./submariner-collect-full-diagnostics.sh /path/to/kubeconfig1 /path/to/kubeconfig2 cluster1 cluster2 "tunnel not connected"
```

**Features:**
- ✓ Validates kubeconfig files and cluster connectivity before collection
- ✓ Validates context names to prevent common mistakes (e.g., same context for both clusters)
- ✓ Collects subctl gather, show, diagnose output from both clusters
- ✓ Captures RouteAgent status and ACM resources
- ✓ Runs connectivity verification tests (default and small packet sizes for MTU testing)
- ✓ Intelligently skips service discovery tests when feature is not enabled
- ✓ Logs executed commands in verify output files for easier debugging
- ✓ Creates compressed tarball for easy sharing: `submariner-diagnostics-TIMESTAMP.tar.gz`

**What it collects:**
- Cluster diagnostics (subctl gather, show, diagnose)
- RouteAgent status from both clusters
- ACM resources (if present)
- Connectivity verification results
- Service discovery verification (only if enabled)
- MTU testing results (small packet size tests)

### `/analyze-offline`

Analyze Submariner diagnostics offline from previously collected data. Use this when you have diagnostic tarballs or directories from clusters but no live cluster access.

**Usage:**
```
/analyze-offline <diagnostics-path> [complaint]
```

**What it does:**
- Extracts and validates diagnostic data (tarball or directory)
- Reads manifest to understand the environment and complaint
- Performs comprehensive root cause analysis
- Applies same troubleshooting logic as live commands
- Provides detailed analysis report with recommended solutions
- References official Submariner documentation with specific sections and search terms

**Diagnoses:**
- Tunnel connectivity issues (ESP blocking, UDP port blocking)
- Gateway pod failures (public IP resolution, crashes)
- MTU/fragmentation problems
- RouteAgent health issues (local routing vs tunnel issues)
- Pod health problems
- Service discovery issues

**Analysis Output:**
- Executive summary
- Detailed findings (tunnel status, pod health, RouteAgent status)
- Root cause analysis with evidence
- Recommended solutions with documentation links
- Additional recommendations

**Input format:**
- Tarball: `submariner-diagnostics-*.tar.gz`
- Directory: Extracted diagnostic data with cluster folders

**Example workflow:**
1. Collect diagnostics (preferably when issue is occurring):
   ```bash
   ./submariner-plugin/scripts/submariner-collect-full-diagnostics.sh \
     /path/to/kubeconfig1 /path/to/kubeconfig2 cluster1 cluster2 "tunnel not up"
   ```

2. Analyze offline:
   ```
   /analyze-offline submariner-diagnostics-20251215-114342.tar.gz
   ```

3. Follow recommendations in the analysis report

### ACM Integration

### `/acm-hub-health`
Check Submariner health on ACM (Advanced Cluster Management) hub cluster by analyzing ManagedClusterAddOn and SubmarinerConfig resources.

**Usage:**
```
/acm-hub-health <hub-kubeconfig>
```

**What it checks:**
- ManagedClusterAddOn resources and their status conditions
- SubmarinerConfig resources and their status conditions
- Gateway node labeling status
- Submariner agent and connection degradation
- Configuration application status

**Provides:**
- Per-cluster health analysis
- Specific issue identification with recommended actions
- Overall ACM hub status summary

## Example Workflows

### Initial Deployment Workflow

1. Deploy the broker to your central cluster:
   ```
   /deploy-broker
   ```

2. Join member clusters to the broker:
   ```
   /deploy
   ```
   Repeat for each cluster you want to connect.

3. Verify the deployment:
   ```
   /show-status
   ```

4. Test connectivity:
   ```
   /verify
   ```

5. If issues arise, run diagnostics:
   ```
   /diagnose
   ```

### Troubleshooting Workflow (Live Cluster Access)

1. Start with comprehensive health check:
   ```
   /troubleshoot-health /path/to/kubeconfig
   ```

2. If tunnel issues detected, run tunnel troubleshooting:
   ```
   /troubleshoot-tunnel /path/to/kubeconfig1 /path/to/kubeconfig2
   ```

3. If ESP blocking detected, apply the fix:
   ```
   /troubleshoot-esp-check /path/to/kubeconfig1 /path/to/kubeconfig2
   ```

4. If connectivity issues persist, check MTU:
   ```
   /troubleshoot-mtu-check /path/to/kubeconfig1 /path/to/kubeconfig2
   ```

5. Verify datapath connectivity:
   ```
   /troubleshoot-datapath-check /path/to/kubeconfig1 /path/to/kubeconfig2
   ```

### Offline Analysis Workflow (No Live Cluster Access)

1. Collect comprehensive diagnostics when issue occurs:
   ```bash
   ./submariner-plugin/scripts/submariner-collect-full-diagnostics.sh \
     /path/to/kubeconfig1 /path/to/kubeconfig2 \
     cluster1 cluster2 \
     "describe the issue here"
   ```

2. Share the generated tarball with your team or support

3. Analyze offline (no cluster access needed):
   ```
   /analyze-offline submariner-diagnostics-20251215-114342.tar.gz
   ```

4. Review the analysis report and follow recommended solutions

5. Apply fixes when you regain cluster access

## About Submariner

Submariner enables direct networking between Pods and Services in different Kubernetes clusters, either on-premises or in the cloud. It provides:

- Cross-cluster L3 connectivity using encrypted tunnels
- Service discovery across clusters
- Support for multiple network plugins (CNIs)
- Multiple cable drivers (Libreswan, WireGuard, VXLAN)

Learn more at [submariner.io](https://submariner.io)

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

Apache 2.0

## Support

For Submariner-specific issues, visit the [Submariner documentation](https://submariner.io/getting-started/) or [GitHub repository](https://github.com/submariner-io/submariner).

For plugin-related issues, please file an issue in this repository.
