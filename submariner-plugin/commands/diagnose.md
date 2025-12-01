---
description: Run comprehensive Submariner diagnostics including all checks and firewall tests
---

# Submariner Comprehensive Diagnostics

Run a comprehensive diagnostic check of the Submariner deployment including:
1. All diagnostic checks using `subctl diagnose all`
2. Firewall diagnostics between clusters

## Step 1: Run All Diagnostics

Run `subctl diagnose all` to perform comprehensive diagnostic checks including:
- Deployment validation
- Connection checks
- Service discovery validation
- Component health checks
- Network configuration validation

Display the results in a clear, formatted way with sections for each diagnostic area.

**Important:** Highlight any issues or warnings found, including:
- Failed diagnostic checks
- Components that are not healthy
- Connections that are not established
- Any error messages or warnings in the output

## Step 2: Firewall Diagnostics

After running all diagnostics, run firewall diagnostics between the clusters:

```bash
subctl diagnose firewall inter-cluster --context cluster1 --remotecontext cluster2
```

This command will:
- Test firewall connectivity between cluster1 and cluster2
- Check if traffic can flow between the clusters
- Identify any firewall rules that might be blocking Submariner traffic
- Verify that the cable driver (VXLAN) can establish connections

Display the firewall diagnostic results clearly, highlighting:
- Whether the firewall test passed or failed
- Any specific ports or protocols that are blocked
- Recommendations for fixing firewall issues

## Summary

At the end, provide a summary that includes:
- Overall diagnostic status (PASS/FAIL/WARNING)
- Number of clusters tested
- Any critical issues that need attention
- Any warnings or recommendations

Format the output in a professional, easy-to-read manner using markdown formatting.
