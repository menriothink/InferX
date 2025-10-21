# GitHub Actions Cache Optimization Guide

## Overview

This project is configured with GitHub Actions caching to accelerate the CI/CD pipeline. By caching build dependencies and intermediate artifacts, we significantly reduce build times.

## Caching Strategy

### 1. **Swift Package Manager (SPM) Dependencies Cache**

#### Cached Content

- `.build` directory
- `~/Library/Developer/Xcode/DerivedData/**/SourcePackages`

#### Cache Key

```yaml
key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}
```

#### How It Works

- Generates cache key based on `Package.resolved` file hash
- Directly uses cached packages when dependency versions haven't changed
- Avoids re-downloading 20+ dependency packages on every build

#### Expected Benefits

- ⚡ **Time Saved**: 3-5 minutes (dependency download)
- 💾 **Cache Size**: ~500MB-1GB
- 🔄 **Invalidation**: When Package.resolved file changes

---

### 2. **DerivedData Cache**

#### Cached Content

- `~/Library/Developer/Xcode/DerivedData`

#### Cache Keys

**Build workflow:**

```yaml
key: ${{ runner.os }}-deriveddata-${{ github.sha }}
restore-keys: ${{ runner.os }}-deriveddata-
```

**Release workflow:**

```yaml
key: ${{ runner.os }}-release-deriveddata-${{ hashFiles('**/*.swift') }}
restore-keys: ${{ runner.os }}-release-deriveddata-
```

#### How It Works

- Caches Xcode build intermediate artifacts
- Supports incremental builds (only recompiles modified files)
- Build uses commit SHA, Release uses code hash

#### Expected Benefits

- ⚡ **Time Saved**: 5-10 minutes (incremental compilation)
- 💾 **Cache Size**: ~2-4GB
- 🔄 **Invalidation**:
  - Build: Every commit (exact match)
  - Release: When Swift code changes

---

## Cache Hierarchy

### Restore Keys Strategy

```
Priority 1: Exact match → macOS-spm-abc123
Priority 2: Prefix match → macOS-spm-
Priority 3: No cache → Full download/build
```

Design Benefits:

- Prioritizes completely matching cache
- Falls back to most recent cache if no exact match
- Avoids starting completely from scratch

---

## Performance Comparison

### First Build (No Cache)

```
1. Checkout                     ~10s
2. Setup SSH                    ~5s
3. Resolve Dependencies         ~180s  ← Download SPM packages
4. Build Project                ~600s  ← Full compilation
5. Run Tests                    ~120s
───────────────────────────────────
Total:                          ~915s (15 minutes)
```

### Subsequent Build (With Cache, No Code Changes)

```
1. Checkout                     ~10s
2. Setup SSH                    ~5s
3. Restore SPM Cache            ~30s   ← Restore from cache
4. Restore DerivedData Cache    ~45s   ← Restore from cache
5. Build Project                ~60s   ← Incremental compilation
6. Run Tests                    ~120s
───────────────────────────────────
Total:                          ~270s (4.5 minutes)
```

### Subsequent Build (With Cache, Minor Code Changes)

```
1. Checkout                     ~10s
2. Setup SSH                    ~5s
3. Restore SPM Cache            ~30s   ← Dependencies unchanged
4. Restore DerivedData Cache    ~45s   ← Partially usable
5. Build Project                ~180s  ← Only modified files
6. Run Tests                    ~120s
───────────────────────────────────
Total:                          ~390s (6.5 minutes)
```

**🎯 Time Savings: 40-70%**

---

## Cache Management

### View Caches

On GitHub repository page:

1. Go to `Actions` tab
2. Left sidebar → `Management` → `Caches`
3. View all cache sizes and usage times

### Cache Limits

- **Per repository limit**: 10GB
- **Cache expiration**: Auto-delete after 7 days unused
- **Cache priority**: Most recently used caches prioritized

### Clear Cache

If encountering cache issues (e.g., dependency version conflicts):

1. **Manual deletion**: Delete from Actions → Caches page
2. **Rename cache key**: Modify cache key prefix in workflow
3. **Force rebuild**: Include `[skip cache]` in commit message

---

## Best Practices

### ✅ Recommended

1. **Layered caching**: Separate SPM and DerivedData caches
2. **Reasonable key strategy**: Generate keys based on actual change conditions
3. **Restore keys**: Provide fallback cache keys
4. **Regular cleanup**: Delete expired or unused caches

### ❌ Avoid

1. **Caching too much**: Don't cache entire Xcode.app
2. **Keys too broad**: Leads to low cache hit rates
3. **Forgetting cleanup**: Accumulates too many useless caches
4. **Caching sensitive data**: Don't cache keys, tokens, etc.

---

## Monitoring and Optimization

### Metrics to Observe

1. **Build time**: View Actions run time trends
2. **Cache hit rate**: Check "Cache restored" logs
3. **Cache size**: Monitor total cache usage

### Continuous Optimization

```bash
# Check cache status in build logs
grep -i "cache" build.log

# Example output:
# Cache restored from key: macOS-spm-abc123
# Cache restored from key: macOS-deriveddata-def456
# Cache saved with key: macOS-spm-abc123
```

---

## Troubleshooting

### Issue: Cache Miss

**Symptoms**: Full dependency download every time

**Diagnosis**:

```bash
# Check if Package.resolved changed
git diff HEAD~1 Package.resolved

# Check Actions logs
# "Cache not found for input keys: ..."
```

**Solution**:

- Ensure Package.resolved is committed to repository
- Check cache key spelling is correct

---

### Issue: Build Fails But Cached Error State

**Symptoms**: Persistent failures even with correct code

**Solution**:

1. Delete corresponding cache
2. Modify cache key (add version number)
3. Push new commit to trigger rebuild

---

### Issue: Cache Size Exceeded

**Symptoms**: "Cache size exceeded" warning

**Solution**:

1. Delete old or infrequently used caches
2. Reduce cache path scope
3. Consider using self-hosted runner (no limits)

---

## Advanced Optimization

### 1. **Conditional Caching**

Use different cache strategies based on branch or event type:

```yaml
- name: Cache with branch prefix
  uses: actions/cache@v4
  with:
    path: ~/Library/Developer/Xcode/DerivedData
    key: ${{ runner.os }}-${{ github.ref_name }}-deriveddata-${{ github.sha }}
```

### 2. **Parallel Caching**

Cache multiple paths simultaneously for faster restoration:

```yaml
- name: Cache multiple paths
  uses: actions/cache@v4
  with:
    path: |
      .build
      ~/Library/Caches/org.swift.swiftpm
      ~/Library/Developer/Xcode/DerivedData
    key: ${{ runner.os }}-all-${{ hashFiles('**/*.swift', '**/Package.resolved') }}
```

### 3. **Incremental Upload**

Use `actions/cache/save` and `actions/cache/restore` to separate cache operations.

---

## Related Links

- [GitHub Actions Cache Documentation](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows)
- [actions/cache Repository](https://github.com/actions/cache)
- [Swift Package Manager Caching](https://www.swiftpackageindex.com/guides)
- [Xcode Build Settings](https://developer.apple.com/documentation/xcode/build-settings-reference)

---

## Changelog

- **2025-10-21**: Initial version, added SPM and DerivedData caching
- Future plans: Add build artifact caching, optimize Release workflow

---

**💡 Tip**: Watch the logs from the first few builds to understand the actual cache effectiveness. If issues arise, refer to the Troubleshooting section of this document.
