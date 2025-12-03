---
description: Diagnose MTU/fragmentation issues in Submariner datapath
---

# Submariner MTU Issue Diagnosis

You are helping diagnose MTU (Maximum Transmission Unit) issues in Submariner multi-cluster connectivity.

## Background

Submariner adds IPSec encapsulation overhead (~60-80 bytes) which reduces the effective MTU. When packets exceed the path MTU, they are fragmented or dropped, causing connectivity issues.

This command will test connectivity with different packet sizes to determine if MTU is the root cause.

## CRITICAL REQUIREMENT

**`subctl verify` ONLY works with Kubernetes context names, NOT kubeconfig paths.**

You MUST:
1. Set `KUBECONFIG` environment variable with both kubeconfig files
2. Retrieve context names using `kubectl config get-contexts`
3. Use `--context <contextName>` and `--tocontext <contextName>` with context NAMES

**DO NOT** use kubeconfig paths with `subctl verify` - it will not work.

## Your Task

### Phase 1: Get Cluster Information

**Check if kubeconfigs were provided as parameters:**
- This command can be invoked as `/submariner:troubleshoot-mtu-check <kubeconfig1> <kubeconfig2>`
- If both kubeconfig paths are provided as parameters, use them directly
- If not provided, ask the user for them

Ask the user for (if not provided as parameters):
- Kubeconfig path for **cluster 1**
- Kubeconfig path for **cluster 2**

### Phase 2: Setup KUBECONFIG and Retrieve Context Names

**This is a REQUIRED step - you cannot skip this!**

1. **Set KUBECONFIG environment variable with BOTH kubeconfig files:**
```bash
export KUBECONFIG=<kubeconfig1>:<kubeconfig2>
```

2. **Retrieve the context names:**
```bash
kubectl config get-contexts
```

The output will show something like:
```
CURRENT   NAME          CLUSTER       AUTHINFO
*         cluster1      cluster1      admin
          cluster2      cluster2      admin
```

**Extract the context names from the NAME column** (e.g., `cluster1`, `cluster2`).

You will use these context NAMES (not the kubeconfig paths) in all `subctl verify` commands.

### Phase 3: Test with Default Packet Size

Explain to the user:
```
Testing connectivity with default packet size (~3000 bytes)...
This test is expected to fail if MTU is the issue.
```

**Run the test using context NAMES:**
```bash
export KUBECONFIG=<kubeconfig1>:<kubeconfig2>
subctl verify --context <contextName1> --tocontext <contextName2> --only connectivity
```

**IMPORTANT:** Use the context NAMES from Phase 2, NOT the kubeconfig paths!

**Record the result**: PASS or FAIL

### Phase 4: Test with Small Packet Size

Explain to the user:
```
Testing connectivity with small packet size (300 bytes)...
If this passes while the default size fails, MTU is confirmed as the root cause.
```

**Run the test with small packets using context NAMES:**
```bash
export KUBECONFIG=<kubeconfig1>:<kubeconfig2>
subctl verify --context <contextName1> --tocontext <contextName2> --packet-size 300 --only connectivity
```

**IMPORTANT:** Again, use context NAMES, NOT kubeconfig paths!

**Record the result**: PASS or FAIL

### Phase 5: Analyze Results and Provide Diagnosis

Compare the two test results:

**SCENARIO 1: Default FAIL, Small Packets PASS ✓**
```
=== MTU ISSUE CONFIRMED ===

Test Results:
✗ Default packet size (~3000 bytes): FAILED
✓ Small packet size (300 bytes): PASSED

DIAGNOSIS:
This pattern confirms an MTU/fragmentation issue. The tunnel is working
but cannot handle larger packets due to IPSec encapsulation overhead.

ROOT CAUSE:
Submariner adds ~60-80 bytes of IPSec overhead. When the original packet
size + overhead exceeds the path MTU, packets are fragmented or dropped.

RECOMMENDED SOLUTIONS:

Option 1: Apply TCP MSS Clamping (Recommended)
--------------------------------------------
This fixes TCP traffic by limiting the Maximum Segment Size.

What it does:
- Annotates gateway nodes with submariner.io/tcp-clamp-mss=1200
- Limits TCP segment size to avoid fragmentation
- Works for most TCP-based applications

Steps:
1. Find and annotate gateway nodes on BOTH clusters
2. Restart RouteAgent pods on BOTH clusters
3. Verify the fix works

Why both clusters?
- Tests are bidirectional (cluster1↔cluster2)
- Cannot determine which direction has the issue
- Safer to apply to both

Option 2: Increase Path MTU (Network-level fix)
------------------------------------------------
If you control the network infrastructure, increase MTU to support jumbo frames.

Requirements:
- Increase MTU on gateway node network interfaces
- Increase MTU on all switches/routers in the path
- May not be feasible in cloud environments

Option 3: Accept the Limitation
--------------------------------
If other options aren't feasible:
- Limit application packet sizes
- Use protocols that handle fragmentation better
```

**Ask the user:** "Would you like me to guide you through Option 1 (TCP MSS Clamping)?"

**SCENARIO 2: Both PASS ✓**
```
=== NO MTU ISSUE DETECTED ===

Test Results:
✓ Default packet size (~3000 bytes): PASSED
✓ Small packet size (300 bytes): PASSED

DIAGNOSIS:
Both packet sizes work fine. MTU is NOT the issue.

If you're experiencing connectivity problems, the root cause is something else.

RECOMMENDED NEXT STEP:
Run: /submariner:troubleshoot-health <kubeconfig>
```

**SCENARIO 3: Both FAIL ✗**
```
=== NOT AN MTU ISSUE ===

Test Results:
✗ Default packet size (~3000 bytes): FAILED
✗ Small packet size (300 bytes): FAILED

DIAGNOSIS:
Even small packets are failing. This is NOT an MTU issue.
More fundamental connectivity problem exists.

POSSIBLE CAUSES:
- Tunnel not established
- Firewall blocking traffic
- Routing issues
- Network policy blocking

RECOMMENDED NEXT STEP:
Run: /submariner:troubleshoot-health <kubeconfig>
```

**SCENARIO 4: Default PASS, Small FAIL (Unexpected) ⚠**
```
=== UNEXPECTED RESULT ===

Test Results:
✓ Default packet size (~3000 bytes): PASSED
✗ Small packet size (300 bytes): FAILED

DIAGNOSIS:
Unusual pattern - likely a transient issue or test framework problem.

RECOMMENDED NEXT STEP:
Re-run the tests to verify results are consistent.
```

### Phase 6: Guide Through TCP MSS Clamping (If User Agrees)

If user wants to apply TCP MSS clamping:

**For Cluster 1:**
```bash
# Step 1: Find gateway nodes
kubectl get nodes -l submariner.io/gateway=true --kubeconfig <kubeconfig1>

# Step 2: Annotate each gateway node (repeat for each gateway node)
kubectl annotate node <gateway-node-name> submariner.io/tcp-clamp-mss=1200 --kubeconfig <kubeconfig1>

# Step 3: Restart RouteAgent pods
kubectl delete pod -n submariner-operator -l app=submariner-routeagent --kubeconfig <kubeconfig1>

# Step 4: Wait for pods to be ready
kubectl wait --for=condition=Ready pod -n submariner-operator -l app=submariner-routeagent --timeout=60s --kubeconfig <kubeconfig1>
```

**For Cluster 2:**
```bash
# Step 1: Find gateway nodes
kubectl get nodes -l submariner.io/gateway=true --kubeconfig <kubeconfig2>

# Step 2: Annotate each gateway node (repeat for each gateway node)
kubectl annotate node <gateway-node-name> submariner.io/tcp-clamp-mss=1200 --kubeconfig <kubeconfig2>

# Step 3: Restart RouteAgent pods
kubectl delete pod -n submariner-operator -l app=submariner-routeagent --kubeconfig <kubeconfig2>

# Step 4: Wait for pods to be ready
kubectl wait --for=condition=Ready pod -n submariner-operator -l app=submariner-routeagent --timeout=60s --kubeconfig <kubeconfig2>
```

**Verify the fix:**
```bash
# Wait 10-15 seconds for changes to take effect
sleep 15

# Re-run datapath verification with context NAMES
export KUBECONFIG=<kubeconfig1>:<kubeconfig2>
subctl verify --context <contextName1> --tocontext <contextName2> --only connectivity
```

Expected result: All tests should now pass.

**Verify annotation is applied:**
```bash
# Check cluster 1
kubectl get nodes -l submariner.io/gateway=true -o jsonpath='{.items[*].metadata.annotations.submariner\.io/tcp-clamp-mss}' --kubeconfig <kubeconfig1>

# Check cluster 2
kubectl get nodes -l submariner.io/gateway=true -o jsonpath='{.items[*].metadata.annotations.submariner\.io/tcp-clamp-mss}' --kubeconfig <kubeconfig2>
```

Should output: `1200` for both clusters.

## Important Notes

**About subctl verify Requirements:**
- **CRITICAL:** `subctl verify` ONLY accepts `--context` and `--tocontext` with context NAMES
- **DO NOT** use kubeconfig paths with `--context` - it expects context names only
- **MUST** set `KUBECONFIG` environment variable with both kubeconfig files
- **MUST** retrieve context names with `kubectl config get-contexts` first

**About the Testing Process:**
- Default packet size: ~3000 bytes (realistic application traffic)
- Small packet size: 300 bytes (well below any MTU limit)
- If default fails but small succeeds → MTU issue confirmed

**About TCP MSS Clamping:**
- MSS value 1200 is a safe starting point
- Can be tuned between 1100-1400 if needed
- Must apply to ALL gateway nodes in each cluster
- Requires RouteAgent pod restart to take effect
- Setting is persistent across restarts

**MSS Value Tuning:**
If tests still fail with MSS=1200, try lower values:
```bash
# More aggressive clamping
kubectl annotate node <gateway-node> submariner.io/tcp-clamp-mss=1100 --overwrite --kubeconfig <kubeconfig>

# Then restart RouteAgent pods and test again
```

**To Remove the Fix:**
```bash
# Remove annotation
kubectl annotate node <gateway-node> submariner.io/tcp-clamp-mss- --kubeconfig <kubeconfig>

# Restart RouteAgent pods
kubectl delete pod -n submariner-operator -l app=submariner-routeagent --kubeconfig <kubeconfig>
```

Be clear in diagnosis, present options, and let the user decide!
