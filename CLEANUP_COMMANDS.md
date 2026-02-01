# System Cleanup Commands

## CRITICAL: Run these commands to free 45-50GB and stop crashes

### 1. Identify what's in the 41GB CloudDocs session folder

```bash
ls -lah ~/Library/Application\ Support/CloudDocs/session/
```

### 2. Clear application caches (safe to delete)

```bash
# Homebrew cache (79MB)
rm -rf ~/Library/Caches/Homebrew/*

# Google cache (84MB)
rm -rf ~/Library/Caches/Google/*

# Playwright cache (127MB)
rm -rf ~/Library/Caches/ms-playwright-go/*

# Node-gyp cache (64MB)
rm -rf ~/Library/Caches/node-gyp/*

# Pip cache (47MB)
rm -rf ~/Library/Caches/pip/*
```

### 3. Remove Docker Desktop (not needed - using cloud)

```bash
rm -rf ~/Library/Application\ Support/Docker\ Desktop
```

### 4. Check Google Drive sync status

```bash
# List Google Drive files taking up space
du -sh ~/Library/Application\ Support/Google/* | sort -hr
```

### 5. Verify disk space freed

```bash
df -h | grep "/System/Volumes/Data"
```

## CloudDocs Session Folder (41GB)

**WARNING**: The 41GB is in `~/Library/Application Support/CloudDocs/session/`

This is likely iCloud sync cache. Options:

1. **Safe**: Let iCloud finish syncing, then it will clear automatically
2. **Manual**: Disable iCloud Drive temporarily in System Settings
3. **Nuclear**: Delete the session folder (may require re-sync)

**Recommended**: Check what's syncing first with the ls command above.

## Google Drive - Switch to Stream Mode

To make Google Drive cloud-only (no local copies):

1. Open Google Drive app
2. Settings → Preferences
3. Select "Stream files" instead of "Mirror files"
4. This will free up ~4GB immediately

## Monitor CPU Usage

After cleanup, monitor these processes:

```bash
# Should see significant reduction in CPU usage
ps aux | grep -E "(cloudd|fileproviderd|bird)" | grep -v grep
```

Target: All processes should be <50% CPU

## Verification

After running cleanup:

```bash
# Check disk usage (should be <80%)
df -h

# Check available space (should be >40GB)
df -h | grep "/System/Volumes/Data" | awk '{print $4}'

# Verify no large AI models
find ~ -name "*.gguf" -o -name "*.bin" -type f -size +100M 2>/dev/null
```
