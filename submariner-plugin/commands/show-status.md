---
description: Show Submariner connection status
---

# Submariner Status Display

Display the current state of your Submariner deployment. This is a quick, informational view without analysis or troubleshooting.

## Your Task

### Phase 1: Get Cluster Information

Ask the user for:
- Kubeconfig path for the cluster to check
- Custom namespace (optional, default: submariner-operator)

### Phase 2: Gather Status Information

Run the following commands to collect status:

**1. Show Connection Status:**
```bash
subctl show connections --kubeconfig <kubeconfig-path>
```

**2. Show All Submariner Components:**
```bash
subctl show all --kubeconfig <kubeconfig-path>
```

**3. Show Pod Status:**
```bash
kubectl get pods -n <namespace> --kubeconfig <kubeconfig-path>
```

### Phase 3: Display Status

Format the output in a clear, readable way:

```
=== SUBMARINER STATUS ===

CONNECTIONS:
[Output from subctl show connections]

PODS:
[Output from kubectl get pods]

COMPONENTS:
[Output from subctl show all]
```

### Important Notes

- This is an **informational command only** - no analysis or troubleshooting
- Do NOT provide recommendations or next steps
- Do NOT analyze health or diagnose issues
- Simply display the current state in a clean format

**For troubleshooting and diagnostics, use:** `/submariner:troubleshoot-health`
