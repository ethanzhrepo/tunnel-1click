## Summary
- bump `version` from `v26.10.31` to `v26.11.9`
- keep installer behavior unchanged
- align the pinned Xray release with upstream

## Upstream
- https://github.com/XTLS/Xray-core/releases/tag/v26.11.9

## Test Plan
- [x] bash tests/run.sh tests/common_test.sh tests/bootstrap_test.sh tests/xray_test.sh tests/render_test.sh tests/targets_test.sh tests/check_test.sh tests/probe_test.sh tests/host_install_test.sh tests/host_update_test.sh tests/version_bump_test.sh
