# Test Marketplace

A local plugin marketplace for testing and developing Claude Code plugins before publishing.

## Overview

This directory serves as a local plugin marketplace that allows you to install and test Claude Code plugins directly from your filesystem without needing to publish them to a remote registry.

## Directory Structure

```
test-marketplace/
├── README.md                          # This file
└── submariner-plugin/                 # Submariner plugin for multi-cluster K8s
    ├── README.md                      # Plugin documentation
    ├── QUICKSTART.md                  # Quick start guide
    └── commands/                      # Plugin slash commands
        ├── deploy-broker.md           # Deploy Submariner broker
        ├── join.md                    # Join cluster to broker
        ├── show-status.md             # Show Submariner connection status
        ├── uninstall.md               # Uninstall Submariner
        ├── acm-hub-health.md          # Check Submariner health on ACM hub
        ├── analyze-offline.md         # Analyze diagnostics offline
        ├── troubleshoot-health.md     # Comprehensive health check
        ├── troubleshoot-tunnel.md     # Troubleshoot tunnel connectivity
        ├── troubleshoot-esp-check.md  # Test and fix ESP firewall blocking
        ├── troubleshoot-mtu-check.md  # Diagnose MTU/fragmentation issues
        └── troubleshoot-datapath-check.md  # Verify end-to-end datapath
```

## Installing the Submariner Plugin Locally

### Method 1: Install from Local Directory (Recommended for Development)

Install the plugin directly from this marketplace directory:

```bash
# From the root of your project
claude plugins install ./test-marketplace/submariner-plugin

# Or if you're already in the test-marketplace directory
claude plugins install ./submariner-plugin
```

### Method 2: Install Using Symlink

Create a symlink to make the plugin available globally:

```bash
# Create a symlink in Claude Code's plugin directory
ln -s $(pwd)/test-marketplace/submariner-plugin ~/.claude/plugins/submariner-plugin

# Or if using a custom plugin directory
ln -s $(pwd)/test-marketplace/submariner-plugin /path/to/claude/plugins/submariner-plugin
```

### Method 3: Copy to Plugin Directory

Copy the plugin directory to Claude Code's plugin directory:

```bash
# Copy to the default plugin directory
cp -r test-marketplace/submariner-plugin ~/.claude/plugins/

# Or if using a custom plugin directory
cp -r test-marketplace/submariner-plugin /path/to/claude/plugins/
```

## Verifying Installation

After installation, verify the plugin is available:

```bash
# List installed plugins
claude plugins list

# You should see 'submariner-plugin' in the list
```

In Claude Code, you can also check available commands:

```
/submariner:
```

This should show autocomplete suggestions for all Submariner commands:

**Deployment & Setup:**
- `/submariner:deploy-broker` - Deploy Submariner broker to the cluster
- `/submariner:join` - Join cluster to Submariner broker
- `/submariner:uninstall` - Uninstall Submariner components

**Status & Monitoring:**
- `/submariner:show-status` - Show Submariner connection status
- `/submariner:acm-hub-health` - Check Submariner health on ACM hub cluster

**Troubleshooting:**
- `/submariner:troubleshoot-health` - Comprehensive health check and troubleshooting
- `/submariner:troubleshoot-tunnel` - Troubleshoot why tunnels are not connected
- `/submariner:troubleshoot-esp-check` - Test and fix ESP protocol firewall blocking
- `/submariner:troubleshoot-mtu-check` - Diagnose MTU/fragmentation issues
- `/submariner:troubleshoot-datapath-check` - Verify end-to-end datapath connectivity

**Diagnostics:**
- `/submariner:analyze-offline` - Analyze Submariner diagnostics offline from collected data

## Command Usage Guide

### When to Use Each Command

**Getting Started:**
1. First, deploy a broker: `/submariner:deploy-broker`
2. Then, join your clusters: `/submariner:join`
3. Verify the connection: `/submariner:show-status`

**Monitoring & Health Checks:**
- Use `/submariner:show-status` for quick connection status
- Use `/submariner:acm-hub-health` if using ACM (Advanced Cluster Management)
- Use `/submariner:troubleshoot-health` for comprehensive health analysis

**When Things Go Wrong:**
- Start with `/submariner:troubleshoot-health` for overall diagnosis
- If tunnel is not connected: `/submariner:troubleshoot-tunnel`
- If you suspect firewall issues: `/submariner:troubleshoot-esp-check`
- If connectivity works but is slow/unstable: `/submariner:troubleshoot-mtu-check`
- To verify full datapath: `/submariner:troubleshoot-datapath-check`

**Offline Analysis:**
- Use `/submariner:analyze-offline` to analyze diagnostic data without cluster access
- Useful for support cases, post-mortems, or when cluster access is limited

**Cleanup:**
- Use `/submariner:uninstall` to remove Submariner from your cluster

## Updating the Plugin

After making changes to the plugin:

```bash
# If installed via symlink, changes are automatically reflected
# No action needed

# If installed via copy, reinstall:
claude plugins uninstall submariner-plugin
claude plugins install ./test-marketplace/submariner-plugin
```

## Uninstalling the Plugin

To remove the plugin:

```bash
# Uninstall the plugin
claude plugins uninstall submariner-plugin

# If you created a symlink, remove it
rm ~/.claude/plugins/submariner-plugin

# If you copied the plugin, remove the directory
rm -rf ~/.claude/plugins/submariner-plugin
```


## Additional Resources

- [Claude Code Plugin Documentation](https://docs.anthropic.com/claude-code/plugins)
- [Submariner Plugin README](./submariner-plugin/README.md)
- [Submariner Documentation](https://submariner.io)
- [Submariner GitHub](https://github.com/submariner-io/submariner)

## Contributing

To contribute improvements to plugins in this marketplace:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally using the installation methods above
5. Submit a pull request

