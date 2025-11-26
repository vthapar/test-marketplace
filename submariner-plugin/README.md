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

### `/status`
Display comprehensive status of Submariner components and connections including gateway nodes, cable connections, and service discovery.

**Usage:**
```
/status
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

## Example Workflow

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
   /status
   ```

4. Test connectivity:
   ```
   /verify
   ```

5. If issues arise, run diagnostics:
   ```
   /diagnose
   ```

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
