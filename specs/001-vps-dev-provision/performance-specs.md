# Performance Specifications - Complete Reference

**Purpose**: Comprehensive performance requirements and benchmarks  
**Created**: December 23, 2025  
**Feature**: [spec.md](spec.md) | [plan.md](plan.md) | [research.md](research.md)

---

## Timing Requirements

### Complete Provisioning Time

**Requirement**: ≤15 minutes on target hardware (FR-006, NFR-001, SC-004)

**Target Hardware** (FR-006, Plan, Assumptions #4):
- RAM: 4GB
- CPU: 2 vCPU cores
- Disk: 25GB SSD (Digital Ocean standard)
- Network: 1 Gbps connection (DO datacenter standard)
- Geographic: US/EU datacenter (baseline for measurements)

**Performance Guarantee**:
- Minimum hardware (2GB RAM, 1 vCPU): ≤20 minutes
- Recommended hardware (4GB RAM, 2 vCPU): ≤15 minutes
- Enhanced hardware (8GB RAM, 4 vCPU): ≤12 minutes

### Per-Phase Timing Estimates

**Phase Breakdown** (Target: 4GB/2vCPU):

```
Phase                    Duration    % of Total   Cumulative
---------------------------------------------------------------
1. system-prep          120s (2m)      13%         2m
2. desktop-install      270s (4.5m)    30%         6.5m
3. rdp-config           60s (1m)       7%          7.5m
4. user-creation        30s (0.5m)     3%          8m
5. ide-vscode           90s (1.5m)     10%         9.5m
6. ide-cursor           90s (1.5m)     10%         11m
7. ide-antigravity      90s (1.5m)     10%         12.5m
8. terminal-setup       30s (0.5m)     3%          13m
9. dev-tools            60s (1m)       7%          14m
10. verification        60s (1m)       7%          15m
---------------------------------------------------------------
TOTAL                   900s (15m)     100%        15m
```

**Phase Timing Tolerances**:
- Individual phase variance: ±20%
- Total provisioning variance: ±10% (13.5-16.5 minutes acceptable)
- Network-dependent phases (desktop-install, IDEs): ±30%

**Parallel Optimization** (Applied):
- IDEs install in parallel: 90s instead of 270s (saves 3 minutes)
- Adjusted total with parallelization: ~12 minutes typical

### RDP Session Initialization Time

**Requirement**: ≤10 seconds (NFR-002)

**Measurement Points**:
1. User enters credentials: T0
2. Authentication completes: T0 + 2s
3. X session starts: T0 + 5s
4. Desktop visible: T0 + 8s
5. Desktop fully interactive: T0 + 10s

**Performance Targets**:
- Authentication: ≤2 seconds
- X server startup: ≤3 seconds
- XFCE initialization: ≤3 seconds
- Window manager ready: ≤2 seconds

**Factors Affecting Performance**:
- First connection: ~10 seconds
- Reconnection to existing session: ~3 seconds
- Network latency impact: +0-2 seconds

### IDE Launch Time

**Requirement**: ≤10 seconds from click to usable interface (NFR-003, SC-002)

**Per-IDE Targets**:
- VSCode: ≤8 seconds
- Cursor: ≤9 seconds (Electron-based, slightly heavier)
- Antigravity: ≤10 seconds

**Measurement Method**:
```bash
# Launch timing test
time_ide_launch() {
  local start=$(date +%s%N)
  $IDE_COMMAND &
  local pid=$!
  
  # Wait for window to appear
  while ! xdotool search --pid $pid 2>/dev/null; do
    sleep 0.1
  done
  
  local end=$(date +%s%N)
  local duration=$(( (end - start) / 1000000 ))
  echo "Launch time: ${duration}ms"
}
```

### Idempotent Re-run Time

**Requirement**: ≤5 minutes for validation-only mode (Plan)

**Breakdown**:
```
Phase                    First Run    Re-run (Idempotent)
----------------------------------------------------------
system-prep             120s          15s (validation only)
desktop-install         270s          20s (check installed)
rdp-config              60s           10s (verify config)
user-creation           30s           5s (user exists check)
ide-vscode              90s           10s (version check)
ide-cursor              90s           10s (version check)
ide-antigravity         90s           10s (version check)
terminal-setup          30s           5s (config exists)
dev-tools               60s           10s (package checks)
verification            60s           60s (full validation)
----------------------------------------------------------
TOTAL                   900s          155s (~2.5 minutes)
```

**Performance Guarantee**: ≤5 minutes (300s) with 95% margin

### Verification Phase Timing

**Requirement**: ≤60 seconds (included in 15-minute total)

**Verification Checks Timing**:
```
Check Type              Duration    Count    Total
----------------------------------------------------
Service status          1s          4        4s
Executable existence    0.5s        10       5s
Port accessibility      2s          2        4s
IDE launch test         10s         3        30s
Configuration verify    1s          5        5s
Permission checks       0.5s        8        4s
Library dependencies    2s          3        6s
Miscellaneous           -           -        2s
----------------------------------------------------
TOTAL                                        60s
```

### Rollback Operation Timing

**Requirement**: ≤5 minutes for complete rollback

**Rollback Performance**:
- Transaction log reading: ≤10 seconds
- Package uninstallation: ≤120 seconds (2 minutes)
- Config file restoration: ≤30 seconds
- User removal: ≤10 seconds
- Service cleanup: ≤20 seconds
- Verification: ≤60 seconds
- **Total**: ≤250 seconds (~4 minutes)

**Factors**:
- Number of packages installed: 50-100 packages typically
- Configuration files modified: 20-30 files
- Services to stop: 4-6 services

### Operation Timeouts

**Timeout Values for All Operations**:

```yaml
network_operations:
  package_download: 300s      # Per package download
  repository_update: 180s     # apt-get update
  ide_download: 600s          # Large IDE downloads
  connection_timeout: 30s     # Initial connection
  retry_delay: 5s            # Between retries

package_operations:
  package_install: 600s       # Per package installation
  dpkg_configure: 300s        # Package configuration
  dependency_resolution: 120s # apt-get dependency checks
  post_install_scripts: 180s  # Package post-install hooks

service_operations:
  service_start: 30s          # systemctl start
  service_stop: 30s           # systemctl stop
  service_restart: 60s        # systemctl restart
  service_status: 5s          # systemctl status

verification_operations:
  ide_launch_test: 15s        # IDE launch verification
  service_check: 5s           # Service status check
  port_check: 10s             # Network port accessibility
  file_check: 1s              # File existence check

rollback_operations:
  package_removal: 180s       # Per package uninstall
  config_restore: 5s          # Per file restoration
  total_rollback: 300s        # Complete rollback timeout
```

### Performance Degradation Threshold

**Acceptable Degradation**:
- Total time increase: ≤20% (15min → 18min acceptable)
- Individual phase increase: ≤30%
- IDE launch degradation: ≤5 seconds (10s → 15s)
- RDP initialization degradation: ≤5 seconds (10s → 15s)

**Unacceptable Degradation** (triggers investigation):
- Total time >20 minutes on 4GB/2vCPU
- Any phase >2x estimated duration
- IDE launch >15 seconds
- RDP initialization >15 seconds

**Degradation Triggers**:
- Network congestion: Expected +10-20%
- High repository load: Expected +15%
- Disk I/O contention: Expected +10%
- CPU throttling: Expected +25%

---

## Resource Utilization Requirements

### RAM Requirements

**Minimum RAM**: 2GB (Spec Assumptions #4)
- System: 400MB
- Desktop (XFCE idle): 500MB
- Single IDE: 600MB
- Buffer: 500MB
- **Total**: 2000MB (2GB)

**Recommended RAM**: 4GB (Plan, Spec FR-006)
- System: 400MB
- Desktop (XFCE idle): 500MB
- 3 IDEs: 1800MB (600MB each)
- 2 RDP sessions: 800MB overhead
- Buffer: 500MB
- **Total**: 4000MB (4GB)

**Optimal RAM**: 8GB
- Supports 3+ concurrent RDP sessions
- Multiple IDEs open simultaneously
- Comfortable development experience

### CPU Requirements

**Minimum CPU**: 1 vCPU (Spec Assumptions #4)
- Provisioning time: ~20 minutes
- Single-session performance: acceptable
- Desktop responsiveness: basic

**Recommended CPU**: 2 vCPU (Plan, Spec FR-006)
- Provisioning time: ~15 minutes
- Multi-session performance: good
- Desktop responsiveness: smooth

**Optimal CPU**: 4 vCPU
- Provisioning time: ~12 minutes
- Parallel compilation support
- Excellent multi-session performance

### Disk Space Requirements

**Total Requirement**: 25GB minimum (Spec Assumptions #4)

**Per-Phase Disk Usage**:
```
Component               Install Size   With Cache   Post-Cleanup
------------------------------------------------------------------
Base System (Debian)    2GB           2GB          2GB
XFCE Desktop            1.5GB         2GB          1.5GB
xrdp + dependencies     50MB          100MB        50MB
VSCode                  350MB         450MB        350MB
Cursor                  400MB         500MB        400MB
Antigravity            300MB         400MB        300MB
Git + dev-tools        500MB         700MB        500MB
User home directory    100MB         100MB        100MB
System logs            50MB          50MB         50MB
Provision logs         20MB          20MB         20MB
Backups (/var/backup)  500MB         500MB        500MB
APT cache              -             2GB          200MB
Temporary files        -             500MB        0MB
------------------------------------------------------------------
TOTAL                  5.77GB        9.42GB       5.97GB
Available for work     19.23GB       15.58GB      19.03GB
```

### Temporary Disk Space

**Temporary Storage** (during provisioning):
- APT package cache: 2GB
- Downloaded .deb files: 1GB
- IDE installers: 1.5GB
- Extraction workspace: 500MB
- Transaction logs: 50MB
- **Peak temporary usage**: ~5GB

**Cleanup After Provisioning**:
- `apt-get clean`: Removes ~1.8GB
- Remove IDE installers: ~1GB
- Compress logs: ~20MB savings
- **Reclaimed**: ~2.8GB

### Memory Usage Limits Per Phase

**Phase-by-Phase Memory Profile**:
```
Phase                   RAM Usage    Peak     Note
-------------------------------------------------------
system-prep            600MB         800MB    APT operations
desktop-install        1.2GB         1.5GB    Package extraction
rdp-config             500MB         600MB    Configuration
user-creation          400MB         450MB    Minimal operations
ide-vscode             700MB         900MB    Extraction + install
ide-cursor             700MB         900MB    Extraction + install
ide-antigravity        600MB         800MB    AppImage extraction
terminal-setup         400MB         450MB    Config file edits
dev-tools              600MB         800MB    Package installation
verification           800MB         1GB      Multiple checks
```

**Memory Limit Enforcement**:
- Monitor with `free -m` every 30 seconds
- Alert if available memory <500MB
- Pause non-critical operations if <300MB
- Abort and rollback if <200MB

### CPU Utilization During Provisioning

**CPU Usage Limits**:
- Average utilization: 40-60% (leaves headroom)
- Peak utilization: 80-90% (during package extraction)
- Idle between phases: 5-10%

**Per-Phase CPU Profile**:
```
Phase                   Avg CPU    Peak CPU   Duration
-------------------------------------------------------
system-prep            30%        60%        120s
desktop-install        60%        90%        270s
rdp-config             20%        40%        60s
user-creation          10%        20%        30s
ide-vscode             50%        85%        90s
ide-cursor             50%        85%        90s
ide-antigravity        40%        75%        90s
terminal-setup         10%        15%        30s
dev-tools              40%        70%        60s
verification           30%        60%        60s
```

**CPU Throttling Detection**:
```bash
detect_cpu_throttling() {
  local start_time=$(date +%s)
  # CPU-intensive task
  dd if=/dev/zero bs=1M count=1024 | md5sum >/dev/null 2>&1
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  
  # Expected: ~5 seconds on 2 vCPU
  if [ $duration -gt 10 ]; then
    log "WARN: CPU throttling detected (${duration}s vs expected 5s)"
  fi
}
```

### Peak Resource Usage

**Peak Resource Consumption**:
- **Memory Peak**: 1.5GB (during desktop-install phase)
- **CPU Peak**: 90% (during package extraction)
- **Disk I/O Peak**: 150 MB/s write (package installation)
- **Network Peak**: 50 Mbps (parallel IDE downloads)

**Simultaneous Peaks** (worst case):
- Desktop installation + IDE download
- Memory: 2GB
- CPU: 85%
- Disk I/O: 120 MB/s
- Network: 40 Mbps

### Resource Monitoring

**Monitoring Strategy**:
```bash
# Continuous resource monitoring
monitor_resources() {
  while true; do
    local timestamp=$(date -Iseconds)
    local mem_used=$(free -m | awk 'NR==2{print $3}')
    local mem_avail=$(free -m | awk 'NR==2{print $7}')
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local disk_avail=$(df / | awk 'NR==2{print $4}')
    
    echo "$timestamp,MEM:${mem_used}MB,AVAIL:${mem_avail}MB,CPU:${cpu_usage}%,DISK:${disk_avail}KB" \
      >> /var/log/vps-provision/resources.csv
    
    # Alert on critical levels
    if [ $mem_avail -lt 300 ]; then
      log "CRITICAL: Available memory below 300MB"
    fi
    
    if [ $disk_avail -lt 5242880 ]; then  # 5GB
      log "CRITICAL: Available disk space below 5GB"
    fi
    
    sleep 10
  done
}
```

**Metrics Collected**:
- Memory usage (used/available)
- CPU utilization (user/system/idle)
- Disk space (available/used)
- I/O operations (read/write)
- Network bandwidth (download/upload)
- Process count
- Load average (1/5/15 min)

---

## Network Performance

### Network Bandwidth Requirement

**Minimum Bandwidth**: 10 Mbps (Spec Dependencies)
- Provisioning time: ~20 minutes (acceptable degradation)
- Large package downloads: 2-3 minutes each

**Recommended Bandwidth**: 50 Mbps (baseline)
- Provisioning time: ~15 minutes (target)
- Large package downloads: 30-45 seconds each

**Optimal Bandwidth**: 100+ Mbps (DO standard)
- Provisioning time: ~12 minutes
- Large package downloads: 15-20 seconds each

### Download Size Estimates

**Total Download Volume**: ~3-4 GB

**Breakdown by Category**:
```
Category                Size        Count    Total
----------------------------------------------------
Debian packages         1.8GB       200      1.8GB
XFCE desktop           800MB       1        800MB
VSCode                 100MB       1        100MB
Cursor                 150MB       1        150MB
Antigravity           120MB       1        120MB
Dependencies           500MB       50       500MB
Package metadata       50MB        -        50MB
Miscellaneous         100MB       -        100MB
----------------------------------------------------
TOTAL                                       3.62GB
```

**Download Time Estimates**:
- 10 Mbps: ~48 minutes (too slow, exceeds target)
- 50 Mbps: ~10 minutes (acceptable)
- 100 Mbps: ~5 minutes (optimal)
- 1 Gbps: ~30 seconds (DO datacenter standard)

### Network Latency Tolerance

**Acceptable Latency**:
- Repository access: ≤100ms RTT
- Package downloads: ≤200ms RTT
- IDE downloads: ≤300ms RTT

**Impact of High Latency**:
- 100ms latency: +5% provisioning time
- 200ms latency: +10% provisioning time
- 500ms latency: +25% provisioning time
- 1000ms latency: +50% provisioning time (unacceptable)

**Geographic Variance**:
- Same continent: 20-50ms
- Cross-continent: 150-300ms
- International: 200-500ms

### Parallel Download Limits

**APT Parallel Downloads**: 3 concurrent (default Debian)
```bash
# /etc/apt/apt.conf.d/99vps-provision
Acquire::Queue-Mode "host";
Acquire::http::Pipeline-Depth "5";
```

**IDE Downloads**: Sequential (one at a time)
- Reason: Large files, avoid bandwidth saturation
- VSCode → Cursor → Antigravity

**Parallel Installation** (IDEs):
- Downloads: Sequential
- Installation/Extraction: Parallel (3 concurrent)

### Network Retry Strategy Performance Impact

**Retry Configuration**:
```bash
Acquire::Retries "3"
Acquire::http::Timeout "300"
Acquire::Retry-Delay "5"
```

**Performance Impact**:
- First retry: +5 seconds delay
- Second retry: +10 seconds delay
- Third retry: +15 seconds delay
- **Total max delay**: +30 seconds per failed download

**Expected Failures**:
- Network transient errors: 2-5% of downloads
- Typical retry overhead: +30-60 seconds per provisioning

### Download Timeout Values

**Timeout Configuration**:
- Connection timeout: 30 seconds
- Download timeout: 300 seconds (5 minutes) per file
- Repository update timeout: 180 seconds (3 minutes)
- DNS resolution timeout: 10 seconds

**Large File Timeouts**:
- IDE downloads (100-150MB): 600 seconds (10 minutes)
- Desktop meta-package: 300 seconds (5 minutes)

### Slow Network Degradation Handling

**Network Speed Detection**:
```bash
detect_network_speed() {
  local start=$(date +%s)
  wget -O /dev/null http://speedtest.debian.org/10MB.bin 2>&1 | \
    grep -oP '\d+\s+[KM]B/s' | tail -1
  local end=$(date +%s)
  local duration=$((end - start))
  
  # 10MB in >30s = slow network (<3 Mbps)
  if [ $duration -gt 30 ]; then
    log "WARN: Slow network detected (${duration}s for 10MB)"
    enable_slow_network_mode
  fi
}

enable_slow_network_mode() {
  # Increase timeouts
  export DOWNLOAD_TIMEOUT=900  # 15 minutes
  
  # Use closer mirrors
  select_closest_mirror
  
  # Warn user
  log "Slow network detected. Provisioning may take 25-30 minutes."
}
```

**Degradation Strategy**:
- Network <5 Mbps: Warn user, extend timeouts by 2x
- Network <2 Mbps: Switch to closest mirror, extend timeouts by 3x
- Network <1 Mbps: Abort with error (provisioning not feasible)

### Network Interruption Recovery Time

**Recovery Requirements**:
- Detection time: ≤30 seconds
- Retry attempt: immediate (after delay)
- Maximum retry duration: 5 minutes per operation
- Total recovery time: ≤10 minutes for all operations

**Interruption Handling**:
```bash
download_with_retry() {
  local url=$1
  local output=$2
  local max_retries=3
  local retry_count=0
  
  while [ $retry_count -lt $max_retries ]; do
    if wget -O "$output" "$url" --timeout=300; then
      return 0
    fi
    
    retry_count=$((retry_count + 1))
    log "Download failed, retry $retry_count/$max_retries in 5s..."
    sleep 5
  done
  
  log "ERROR: Download failed after $max_retries attempts"
  return 1
}
```

### Bandwidth Usage Optimization

**Optimization Strategies**:
1. **Package Caching**: Use APT cache for repeated downloads
2. **Compression**: Prefer compressed packages (default)
3. **Incremental Downloads**: Resume interrupted downloads
4. **Mirror Selection**: Use geographically closest mirror
5. **Parallel Limits**: Don't saturate bandwidth (max 3 concurrent)

**Bandwidth Allocation**:
- APT downloads: 70% of available bandwidth
- IDE downloads: 80% of available bandwidth (sequential)
- Verification checks: 10% of available bandwidth

### Connection Pool Limits

**Connection Limits**:
- APT connections: 5 maximum per host
- HTTP connections: 10 maximum total
- Persistent connections: Enabled (HTTP Keep-Alive)
- Connection timeout: 30 seconds idle

**Pool Configuration**:
```bash
# /etc/apt/apt.conf.d/99vps-provision
Acquire::http::Pipeline-Depth "5";
Acquire::http::Max-Pipeline-Depth "10";
Acquire::http::Keep-Alive "true";
Acquire::http::Timeout "300";
```

---

## Desktop Environment Performance

### Desktop Idle Memory Usage

**Requirement**: ≤500MB RAM at idle (Research §2, installation-specs.md)

**Memory Breakdown**:
```
Component               RAM Usage
---------------------------------------
X Server                120MB
XFCE Window Manager     80MB
XFCE Panel              40MB
Thunar (file manager)   60MB
xfce4-terminal          50MB
System services         100MB
Buffer cache            50MB
---------------------------------------
TOTAL                   500MB
```

**Validation**:
```bash
validate_desktop_memory() {
  sleep 30  # Let desktop settle
  local mem_usage=$(ps aux | grep -E 'xfce|Xorg' | \
    awk '{sum+=$6} END {print sum/1024}')
  
  if [ $(echo "$mem_usage > 500" | bc) -eq 1 ]; then
    log "WARN: Desktop memory usage ${mem_usage}MB exceeds 500MB target"
    return 1
  fi
  
  log "✓ Desktop memory usage: ${mem_usage}MB (within target)"
  return 0
}
```

### Desktop CPU Usage at Idle

**Requirement**: ≤2% CPU at idle

**CPU Distribution**:
```
Process                 CPU %
--------------------------------
Xorg                   0.5%
xfwm4                  0.3%
xfce4-panel            0.2%
systemd                0.5%
Other services         0.5%
--------------------------------
TOTAL                  2.0%
```

**Monitoring**:
```bash
check_desktop_cpu_idle() {
  sleep 60  # Wait for idle state
  local cpu_usage=$(top -bn2 -d 10 | grep "Cpu(s)" | tail -n1 | \
    awk '{print $2}' | cut -d'%' -f1)
  
  if [ $(echo "$cpu_usage > 5" | bc) -eq 1 ]; then
    log "WARN: Desktop CPU usage ${cpu_usage}% exceeds 2% target"
  fi
}
```

### Desktop Responsiveness

**Requirement**: Applications respond within 200ms (NFR-003)

**Response Time Targets**:
- Menu open: ≤100ms
- Window switch: ≤50ms
- File browser navigation: ≤200ms
- Application launch: ≤10 seconds (see IDE Launch Time)

**Measurement Method**:
```bash
test_desktop_responsiveness() {
  # Test menu response
  local start=$(date +%s%N)
  xdotool key alt+F1  # Open menu
  xdotool key Escape  # Close menu
  local end=$(date +%s%N)
  local latency=$(( (end - start) / 1000000 ))
  
  if [ $latency -gt 200 ]; then
    log "WARN: Menu latency ${latency}ms exceeds 200ms"
  fi
}
```

### Desktop Startup Time

**Requirement**: ≤20 seconds from service start to desktop ready (installation-specs.md)

**Startup Phases**:
```
Phase                   Duration    Cumulative
------------------------------------------------
LightDM start          3s           3s
X Server init          4s           7s
Session authentication 2s           9s
XFCE session start     5s           14s
Panel/desktop load     4s           18s
Services ready         2s           20s
------------------------------------------------
TOTAL                  20s          20s
```

**Measurement**:
```bash
measure_desktop_startup() {
  local start=$(systemctl show lightdm --property=ActiveEnterTimestamp | \
    cut -d'=' -f2 | date -f - +%s)
  
  # Wait for desktop to be fully loaded
  while ! xdotool search --class xfce4-panel; do
    sleep 0.5
  done
  
  local end=$(date +%s)
  local startup_time=$((end - start))
  
  log "Desktop startup time: ${startup_time}s"
}
```

### Application Launch Overhead

**Requirement**: ≤2 seconds overhead for desktop environment

**Launch Breakdown**:
```
Total IDE launch: 10 seconds
- Application startup: 8 seconds (IDE itself)
- Desktop overhead: 2 seconds (window management, theme, etc.)
```

**Desktop Overhead Includes**:
- Window creation: 0.5s
- Theme rendering: 0.5s
- Compositor: 0.5s
- Desktop integration: 0.5s

### Window Manager Performance

**XFWM4 Performance Requirements**:
- Window creation: ≤50ms
- Window switching: ≤30ms
- Workspace switching: ≤100ms
- Window resizing: 60fps (16.7ms per frame)

**Resource Usage**:
- Memory: 50-80MB
- CPU (idle): 0.3%
- CPU (active): 2-5%

### Rendering Performance

**Graphics Requirements**:
- Frame rate: 30fps minimum (desktop), 60fps target
- Window redraw: ≤33ms (30fps)
- Scrolling: Smooth (60fps in terminals/editors)

**X Server Performance**:
- 2D rendering: GPU-accelerated if available
- Fallback: Software rendering (acceptable for VPS)
- Memory bandwidth: ≤100 MB/s

### Animation Performance

**XFCE Animation Settings**:
- Window animations: Disabled (for performance)
- Menu animations: Minimal (fade only)
- Desktop effects: Disabled
- Compositor: Disabled by default (can enable if GPU present)

**If Animations Enabled**:
- Target frame rate: 30fps
- Animation duration: ≤300ms
- No animations should block user input

### Theme Rendering Overhead

**Theme Performance**:
- Theme load time: ≤2 seconds
- Per-window overhead: ≤50ms
- Theme memory usage: ≤20MB

**Selected Theme** (Adwaita-dark):
- Lightweight CSS-based rendering
- Pre-cached icons
- Optimized for performance

### Compositor Performance

**Compositor Configuration** (disabled by default):
```bash
# If enabled, performance requirements:
xfconf-query -c xfwm4 -p /general/use_compositing -s false

# If user enables:
- VSync: Enabled
- Frame rate: 60fps
- Additional memory: 50MB
- Additional CPU: 1-2%
```

---

## Multi-Session Performance

### Concurrent Session Count

**Requirement**: Up to 3 concurrent RDP sessions without degradation (NFR-004, SC-007)

**Session Limits**:
- Minimum hardware (2GB): 1 session
- Recommended hardware (4GB): 3 sessions
- Enhanced hardware (8GB): 5+ sessions

### Per-Session Resource Allocation

**Resource Allocation per Session** (4GB RAM system):

```
Session #1 (primary):
- RAM: 1.2GB (desktop + IDE)
- CPU: 50% average
- Disk I/O: 10 MB/s

Session #2:
- RAM: 800MB (desktop + browser)
- CPU: 30% average
- Disk I/O: 5 MB/s

Session #3:
- RAM: 600MB (desktop + terminal)
- CPU: 20% average
- Disk I/O: 3 MB/s

System overhead:
- RAM: 400MB
- CPU: 5%
---------------------------------
TOTAL (3 sessions):
- RAM: 3GB used, 1GB buffer
- CPU: 105% (dual-core utilized)
- Disk I/O: 18 MB/s
```

### Multi-Session Memory Overhead

**Memory Overhead Calculation**:

```
Single session:     1500MB
Two sessions:       2600MB  (overhead: 200MB, 7.7%)
Three sessions:     3600MB  (overhead: 300MB, 8.3%)

Formula: Base + (Sessions * Per-Session) + Overhead
Overhead: ~100MB per additional session
```

**Shared Memory Components**:
- Read-only libraries: Shared across sessions
- Desktop themes: Shared
- System binaries: Shared
- User data: Separate per session

### Multi-Session Responsiveness

**Responsiveness Requirement**: No noticeable lag with 3 sessions (NFR-004)

**Performance Targets**:
- Single session latency: ≤50ms
- Two sessions latency: ≤80ms
- Three sessions latency: ≤120ms

**Quality Degradation Thresholds**:
- Acceptable: Latency ≤150ms
- Noticeable: Latency 150-300ms
- Unacceptable: Latency >300ms

### Session Isolation Overhead

**Isolation Mechanisms**:
- Separate X displays: `:10`, `:11`, `:12`
- User namespaces: Kernel-level isolation
- Resource limits: cgroups (optional)

**Performance Impact**:
- Context switching: +2-3ms per switch
- Memory isolation: +50MB per session
- CPU overhead: +1% per session

### Maximum Sustainable Session Count

**Hardware-Based Limits**:

```
Hardware           Max Sessions    Quality
--------------------------------------------
2GB RAM, 1 vCPU   1               Good
4GB RAM, 2 vCPU   3               Good
4GB RAM, 2 vCPU   4               Acceptable
4GB RAM, 2 vCPU   5+              Poor
8GB RAM, 4 vCPU   5               Good
8GB RAM, 4 vCPU   8               Acceptable
16GB RAM, 8 vCPU  10+             Good
```

**Limiting Factors**:
- RAM: Primary constraint
- CPU: Secondary constraint
- Disk I/O: Tertiary constraint

### Session Switching Performance

**Switching Time Requirements**:
- RDP client disconnect/reconnect: ≤3 seconds
- Session resume from disconnected: ≤2 seconds
- Switch between active sessions: ≤1 second

**Session State**:
- Active session: Full resources
- Disconnected session: Reduced resources (CPU)
- Preserved state: All application windows/data

### Session Cleanup Performance

**Cleanup Time**: ≤30 seconds per session

**Cleanup Operations**:
```
Operation               Duration
-----------------------------------
Stop user processes    5s
Kill remaining         3s
Remove temp files      5s
Clean X display        2s
Update session DB      1s
Free memory            10s
Log cleanup            2s
-----------------------------------
TOTAL                  28s
```

### Session Persistence Overhead

**Persistence Mechanism**:
- Session metadata: 1MB per session
- Application state: Variable (50-200MB)
- Total overhead: 50-200MB per disconnected session

**Performance Impact**:
- Save state on disconnect: ≤5 seconds
- Restore state on reconnect: ≤3 seconds
- Memory overhead: 100MB average per session

### Session Recovery Time

**Recovery Scenarios**:

```
Scenario                    Recovery Time
---------------------------------------------
Normal disconnect/reconnect  3s
System reboot               Not supported
xrdp service restart        10s (new session)
X server crash              30s (new session)
Network interruption        Auto-reconnect: 5s
```

---

## I/O Performance

### Disk Read/Write Performance

**Requirements**:
- Sequential read: ≥100 MB/s (SSD expected)
- Sequential write: ≥80 MB/s
- Random read (4K): ≥5000 IOPS
- Random write (4K): ≥2000 IOPS

**Provisioning I/O Pattern**:
- Primarily sequential writes (package installation)
- Some random reads (configuration files)
- Average throughput: 50-80 MB/s during installation

### Filesystem I/O Pattern

**Optimized Patterns**:
```
Phase                   I/O Pattern         Optimization
-----------------------------------------------------------
Package download        Sequential write    Large buffer (1MB)
Package extraction      Random write        Moderate buffer (64KB)
Config modification     Random read/write   Small buffer (4KB)
Log writing            Sequential append   Line buffering
```

**Filesystem Configuration**:
- Filesystem: ext4 (default Debian)
- Mount options: `relatime,errors=remount-ro`
- Journal mode: `data=ordered`

### Log File Write Performance

**Log Writing Requirements**:
- Write latency: ≤10ms per line
- Throughput: ≥1000 lines/second
- Buffer size: 4KB line buffer
- Sync frequency: Every 100 lines or 5 seconds

**Log Volume**:
- Provisioning: ~50,000 lines
- Expected duration: ~60 seconds of logging
- Average rate: ~833 lines/second

### Configuration File I/O

**Config File Performance**:
- Read time: ≤50ms per file
- Write time: ≤100ms per file
- Typical file size: 1-100KB
- Files modified: ~30 during provisioning

### Temporary File I/O

**Temporary Storage Performance**:
- Location: `/tmp` (tmpfs if >2GB RAM, else disk)
- Write speed: ≥200 MB/s (tmpfs) or ≥80 MB/s (disk)
- Volume: ~500MB temporary files
- Cleanup: Automatic on reboot, manual post-provision

### I/O Queue Depth

**Queue Configuration**:
- Queue depth: 32 (default SSD)
- Scheduler: `mq-deadline` (modern kernel default)
- Maximum concurrent I/O: 32 operations

### I/O Scheduler

**Scheduler Selection**:
- SSD: `mq-deadline` or `none`
- HDD: `mq-deadline`
- Default: Auto-detected

**Performance Impact**:
- `mq-deadline`: Good all-around, slight latency penalty
- `none`: Best for NVMe SSD, no overhead
- `bfq`: Fair queuing, better for desktop (optional)

### Disk Cache Utilization

**Cache Strategy**:
```bash
# Kernel page cache
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5

# Readahead for sequential I/O
blockdev --setra 8192 /dev/vda  # 4MB readahead
```

**Cache Effectiveness**:
- Page cache hit rate: >80% target
- Write cache: Enabled
- Read cache: Enabled

### I/O Timeout Values

**Operation Timeouts**:
- Standard file I/O: 30 seconds
- Package extraction: 300 seconds
- Large file copy: 600 seconds
- Network file operations: 180 seconds

### I/O Error Recovery

**Error Handling**:
- Retry count: 3 attempts
- Retry delay: 5 seconds
- Total timeout: Operation timeout + (retries * delay)

**Performance Impact**:
- Successful retry: +5-10 seconds
- Failed operation: Timeout + rollback time

---

## Package Management Performance

### APT Cache Performance

**Cache Requirements**:
- Cache build time: ≤30 seconds
- Cache size: ~150MB
- Cache hit rate: >90% for repeated operations

**Cache Operations**:
```bash
# Update cache
time apt-get update  # Target: <30s

# Cache search
time apt-cache search keyword  # Target: <2s

# Dependency check
time apt-cache depends package  # Target: <1s
```

### Package Download Parallel Limit

**Concurrent Downloads**: 3 parallel (APT default)

**Performance Impact**:
```
1 parallel:  ~15 minutes total
3 parallel:  ~7 minutes total
5 parallel:  ~6 minutes total (diminishing returns)
```

**Optimal**: 3 parallel (balance between speed and resource usage)

### Package Installation Concurrency

**Installation Parallelism**: Sequential (1 at a time)
- Reason: Package post-install scripts may conflict
- Exception: Independent packages can be parallel (requires analysis)

**Future Optimization**:
- Parallel installation of independent packages
- Potential time savings: 2-3 minutes

### Package Verification Performance

**Verification Operations**:
```
Operation                   Time      Per Package
--------------------------------------------------
GPG signature verify       0.5s       0.005s
SHA256 checksum            1.0s       0.01s
Dependency check           2.0s       0.02s
Integrity check            1.5s       0.015s
--------------------------------------------------
Total verification         5s         0.05s
```

**For 100 packages**: ~5 seconds total (cached signatures)

### Dependency Resolution Timeout

**Resolution Time**:
- Simple dependencies: <5 seconds
- Complex dependencies: <30 seconds
- Timeout: 120 seconds

**Complexity Examples**:
- XFCE meta-package: ~20 seconds (50+ dependencies)
- Single IDE: ~5 seconds (10-20 dependencies)

### Package Extraction Performance

**Extraction Requirements**:
- Speed: ≥10 MB/s
- Large package (100MB): ≤10 seconds
- Small package (1MB): ≤1 second

**Bottleneck**: Usually disk I/O, not CPU

### Post-Install Script Timeouts

**Script Execution Timeouts**:
- Standard timeout: 180 seconds (3 minutes)
- Extended timeout: 600 seconds (10 minutes) for large packages
- Critical packages: No timeout (system packages)

**Typical Durations**:
- Simple scripts: 1-5 seconds
- Service configuration: 10-30 seconds
- Complex setup: 60-180 seconds

### Package Database Update Performance

**Database Operations**:
```
Operation                Duration
----------------------------------
dpkg --configure -a     30s
apt-get update          25s
apt-cache gencaches     15s
Update available list   10s
----------------------------------
```

### Package Checksum Verification

**Verification Timeouts**:
- Per-file checksum: 5 seconds
- Per-package: 30 seconds
- Entire provisioning: 120 seconds total

### Package Cleanup Performance

**Cleanup Operations**:
```bash
apt-get clean          # 5-10 seconds, removes ~2GB
apt-get autoclean      # 3-5 seconds, removes old packages
apt-get autoremove     # 10-20 seconds, removes orphaned packages
```

**Total Cleanup Time**: ≤40 seconds

---

## Scaling Requirements

### Performance Degradation on Minimum Hardware

**Minimum Hardware Performance** (2GB RAM, 1 vCPU):
- Provisioning time: 18-20 minutes (+20-33% vs target)
- Memory pressure: Frequent swapping
- CPU saturation: 90-100% during peak phases
- Acceptable: Yes, with warnings

**Degradation Factors**:
- Package extraction: 2x slower
- IDE installations: 1.5x slower
- Concurrent operations: Not feasible

### Performance Improvement on Better Hardware

**Scaling Characteristics**:

```
Hardware             Provision Time    Improvement
---------------------------------------------------
2GB / 1vCPU         20 minutes        Baseline
4GB / 2vCPU         15 minutes        -25%
8GB / 4vCPU         12 minutes        -40%
16GB / 8vCPU        10 minutes        -50%
```

**Diminishing Returns**: Beyond 8GB/4vCPU, gains are minimal

### Scaling Limits

**Upper Limits**:
- Minimum practical provisioning time: ~8 minutes (network-bound)
- Maximum concurrent sessions: ~50 (xrdp configured limit)
- Maximum disk space: No practical limit
- Maximum RAM: No practical limit (but 16GB sufficient)

**Lower Limits**:
- Below 2GB RAM: Not recommended (swapping issues)
- Below 1 vCPU: Not feasible (>30 minute provisioning)
- Below 10GB disk: Insufficient space

### Concurrent Provisioning Impact

**Multi-VPS Provisioning**:

```
Concurrent VPS    Time per VPS    Total Time
----------------------------------------------
1 VPS            15 min          15 min
2 VPS            17 min          17 min (+13%)
3 VPS            20 min          20 min (+33%)
5 VPS            25 min          25 min (+67%)
```

**Bottleneck**: Shared network bandwidth to repositories

### Multi-VPS Provisioning Performance

**Network Bandwidth Sharing**:
- Single VPS: 100 Mbps (full bandwidth)
- 2 VPS: 50 Mbps each
- 5 VPS: 20 Mbps each

**Mitigation Strategies**:
1. Stagger provisioning starts
2. Use local mirror/cache
3. Pre-download packages

### Shared Resource Contention

**Repository Server Contention**:
- Debian mirrors: High capacity, minimal impact
- Microsoft VSCode: Rate limited, +10% time for >3 concurrent
- GitHub releases: Rate limited, potential 429 errors

**Mitigation**:
- Use multiple mirrors
- Implement exponential backoff
- Cache downloads locally

### Network Bandwidth Sharing Impacts

**Impact Matrix**:

```
Shared Clients    Per-Client BW    Provision Time
--------------------------------------------------
1                100 Mbps         15 min
2                50 Mbps          16 min
5                20 Mbps          19 min
10               10 Mbps          25 min
```

### Repository Mirror Load Balancing

**Strategy**:
1. Use geographically closest mirrors
2. Implement round-robin for multiple mirrors
3. Failover on timeout/error

**Mirror Configuration**:
```bash
# Primary mirror
deb http://deb.debian.org/debian bookworm main

# Fallback mirrors
deb http://ftp.us.debian.org/debian bookworm main
deb http://ftp.eu.debian.org/debian bookworm main
```

### Rate Limiting

**Rate Limits**:
- No client-side rate limiting (trust repository capacity)
- Respect HTTP 429 responses (back off exponentially)
- Maximum retry: 3 attempts with 5s, 10s, 20s delays

### Geographic Performance Variance

**Regional Performance**:

```
Region              Latency    Provision Time
---------------------------------------------
US East (DO)       Baseline    15 min
US West            +20ms       15.5 min
Europe             +50ms       16 min
Asia               +150ms      18 min
Australia          +250ms      20 min
```

**Recommendation**: Provision VPS in same region as primary work location

---

## Performance Monitoring

### Performance Metric Collection

**Metrics Collected**:
```
Category          Metrics                          Frequency
-------------------------------------------------------------
Timing            Phase duration, total time       Per phase
Resource          CPU%, RAM MB, Disk MB           Every 10s
Network           Download speed, latency          Per download
I/O               Read/write IOPS, throughput     Every 30s
Application       IDE launch time, RDP init       On event
System            Load average, process count      Every 60s
```

**Storage Format**: CSV for time-series, JSON for summaries

### Timing Instrumentation

**Instrumentation Code**:
```bash
# Phase timing
phase_start() {
  local phase=$1
  PHASE_START[${phase}]=$(date +%s)
  log "Phase started: $phase"
}

phase_end() {
  local phase=$1
  local start=${PHASE_START[${phase}]}
  local end=$(date +%s)
  local duration=$((end - start))
  
  log "Phase completed: $phase in ${duration}s"
  echo "$phase,$duration" >> /var/log/vps-provision/timing.csv
}
```

### Performance Log Requirements

**Log Format** (NFR-018):
```
Timestamp,Phase,Metric,Value,Unit
2025-12-23T10:30:00Z,system-prep,duration,120,seconds
2025-12-23T10:30:00Z,system-prep,cpu_avg,45,percent
2025-12-23T10:30:00Z,system-prep,mem_peak,800,megabytes
```

**Log Retention**: 30 days

### Benchmark Data Collection

**Benchmark Suite**:
```bash
# System benchmarks
benchmark_cpu
benchmark_disk_io
benchmark_network

# Application benchmarks
benchmark_ide_launch
benchmark_rdp_init
benchmark_desktop_startup
```

**Output**: JSON report with comparison to baseline

### Performance Regression Detection

**Regression Detection**:
```bash
detect_regression() {
  local current_time=$1
  local baseline_time=$2
  local threshold=1.2  # 20% slower
  
  if (( $(echo "$current_time > ($baseline_time * $threshold)" | bc -l) )); then
    log "WARN: Performance regression detected"
    log "Current: ${current_time}s vs Baseline: ${baseline_time}s"
    return 1
  fi
  return 0
}
```

### Performance Reporting Format

**Summary Report**:
```json
{
  "session_id": "20251223-103000",
  "total_duration": 900,
  "target_duration": 900,
  "performance_score": 100,
  "phases": [
    {
      "name": "system-prep",
      "duration": 120,
      "target": 120,
      "variance": 0
    }
  ],
  "resource_peaks": {
    "cpu": 85,
    "memory": 1500,
    "disk_io": 150
  }
}
```

### Performance Baseline

**Baseline Conditions**:
- Hardware: 4GB RAM, 2 vCPU, SSD
- Network: 100 Mbps, <50ms latency
- Location: US East datacenter
- Time: Off-peak hours

**Baseline Metrics**: See "Per-Phase Timing Estimates" section

### Performance Comparison Methodology

**Comparison Process**:
1. Collect metrics from current run
2. Load baseline metrics
3. Calculate variance per metric
4. Flag metrics with >20% variance
5. Generate comparison report

### Performance Alert Thresholds

**Alert Levels**:
```
Severity    Threshold               Action
--------------------------------------------
INFO        Within target          Log only
WARN        +20% above target      Log warning
ERROR       +50% above target      Alert user
CRITICAL    +100% above target     Abort & investigate
```

### Performance Data Retention

**Retention Policy**:
- Detailed logs: 7 days
- Summary data: 30 days
- Benchmark results: 90 days
- Historical trends: 1 year (aggregated)

**Storage Volume**: ~50MB per provisioning session

---

## Performance Edge Cases

### Performance Under Resource Contention

**Contention Scenarios**:
- Multiple provisioning operations: +30% time
- Concurrent system updates: +20% time
- High background I/O: +15% time
- Other users active: +10-25% time

**Mitigation**: Resource monitoring and adaptive throttling

### Performance During High I/O Load

**High I/O Conditions**:
- Concurrent database operations: +25% time
- Active backup process: +30% time
- Log aggregation: +10% time

**Detection**: Monitor `iostat` and adapt

### Performance Under Network Congestion

**Congestion Handling**:
- Automatic retry with backoff
- Extended timeouts
- Mirror failover
- Expected degradation: +30-50%

### Performance with Slow Disk

**HDD vs SSD**:
- SSD: 15 minutes (baseline)
- HDD (7200 RPM): 22 minutes (+47%)
- HDD (5400 RPM): 28 minutes (+87%)

**Recommendation**: Require SSD for production use

### Performance with Limited CPU

**CPU Throttling**:
- No throttling: 15 minutes
- 50% throttled: 20 minutes (+33%)
- 75% throttled: 28 minutes (+87%)

**Detection and Warning**: CPU benchmark on start

### Performance Under Memory Pressure

**Memory Constraints**:
- No swapping: 15 minutes
- Light swapping (<100MB): 18 minutes (+20%)
- Heavy swapping (>500MB): 30+ minutes (+100%)

**Mitigation**: Abort if available memory <500MB

### Performance During Peak Repository Load

**Peak Hours**:
- Off-peak (baseline): 15 minutes
- Peak hours (8am-6pm UTC): 17 minutes (+13%)
- Major release day: 22 minutes (+47%)

**Strategy**: Recommend off-peak provisioning

### Performance with High Latency Network

**Latency Impact**:
- <50ms: 15 minutes (baseline)
- 100ms: 16 minutes (+7%)
- 200ms: 18 minutes (+20%)
- 500ms: 23 minutes (+53%)

### Performance with Packet Loss

**Packet Loss Impact**:
- 0% loss: 15 minutes
- 1% loss: 17 minutes (+13%, retries)
- 5% loss: 25 minutes (+67%, many retries)
- 10% loss: Abort (not feasible)

### Performance During Concurrent System Updates

**Update Conflicts**:
- No conflicts: 15 minutes
- unattended-upgrades active: 20 minutes (+33%)
- Manual apt upgrade: 25 minutes (+67%)

**Detection**: Check for lock files, wait or abort

---

## Measurability

### Objective Measurement

**All performance requirements are measurable**:
✅ Time-based: Measured with system clock
✅ Resource-based: Measured with system tools (free, top, iostat)
✅ Network-based: Measured with network monitoring
✅ Application-based: Measured with timing instrumentation

### Performance Test Methodologies

**Testing Approach**:
1. **Baseline Testing**: Establish performance baseline on reference hardware
2. **Regression Testing**: Compare each run against baseline
3. **Load Testing**: Test with concurrent operations
4. **Stress Testing**: Test at resource limits
5. **Endurance Testing**: Multiple consecutive provisions

**Test Environments**:
- Digital Ocean Debian 13 droplets
- Multiple datacenter regions
- Various hardware configurations

### Performance Acceptance Criteria

**Acceptance Thresholds** (SC-004):
- ✅ Complete provisioning: ≤15 minutes (required)
- ✅ RDP initialization: ≤10 seconds (required)
- ✅ IDE launch: ≤10 seconds (required)
- ✅ Multi-session: 3 concurrent without lag (required)
- ✅ Idempotent re-run: ≤5 minutes (required)

### CI/CD Automation

**Automated Performance Tests**:
```yaml
# .github/workflows/performance-test.yml
name: Performance Test
on: [push, pull_request]

jobs:
  performance:
    runs-on: ubuntu-latest
    steps:
      - name: Provision Fresh VPS
      - name: Run Provisioning
      - name: Collect Metrics
      - name: Compare to Baseline
      - name: Fail if Regression
```

### Performance Benchmarking Tools

**Tools Used**:
- `time`: Command timing
- `systemd-analyze`: Boot/service timing
- `iotop`: I/O monitoring
- `nethogs`: Network monitoring
- `stress-ng`: Stress testing
- Custom scripts: Application-level timing

**Custom Tooling**:
- `bin/vps-benchmark`: Complete system benchmark
- `bin/vps-provision-perf`: Provisioning with metrics
- `lib/utils/metrics-collector.sh`: Real-time monitoring

---

## Traceability

### Requirements to Success Criteria

**All performance requirements map to SC-004**:
- Complete provisioning ≤15 min → SC-004
- RDP initialization ≤10s → Derived from SC-001, NFR-002
- IDE launch ≤10s → SC-002, NFR-003
- Multi-session support → SC-007, NFR-004
- Idempotent re-run → SC-008, Plan

### Performance NFRs to User Experience

**NFR Linkage**:
- NFR-001 → User Story 1 (fast setup)
- NFR-002 → User Story 1 (immediate usability)
- NFR-003 → User Story 1 (productive environment)
- NFR-004 → User Story 3 (multi-user collaboration)

### Performance to Hardware Assumptions

**Constraint Mapping**:
- All timing requirements → Spec Assumptions #4 (4GB/2vCPU)
- Disk requirements → Spec Assumptions #4 (25GB)
- Network requirements → Spec Dependencies (stable connectivity)

### Requirements to User Stories

**User Story Alignment**:
- User Story 1: All timing requirements enable one-command setup
- User Story 3: Multi-session requirements enable collaboration
- User Story 4: Idempotency requirements enable rapid replication

### Edge Cases to Requirements

**Edge Case Coverage**:
- Slow network → Network timeout requirements
- Resource contention → Resource monitoring requirements
- Limited hardware → Minimum hardware specifications
- High latency → Timeout and retry specifications

---

## Summary

This document provides complete performance specifications for all 110 checklist items. All performance requirements are:

✅ **Quantified**: Specific numeric targets
✅ **Measurable**: Clear measurement methodologies
✅ **Testable**: Automated testing strategies
✅ **Traceable**: Linked to functional requirements and success criteria
✅ **Achievable**: Based on research and hardware capabilities

**Key Performance Guarantees**:
- 15-minute provisioning on 4GB/2vCPU hardware
- 10-second RDP and IDE launch times
- 3 concurrent sessions without degradation
- 5-minute idempotent re-run validation
- Comprehensive monitoring and alerting

All gaps identified in the checklist have been addressed with complete specifications.
