## Summary

Describe the change and why it belongs in Veil.

## Type

- [ ] Visual module
- [ ] Local signal adapter
- [ ] Compatibility
- [ ] Packaging/install
- [ ] Documentation
- [ ] Advanced/private integration

## Safety

- [ ] Default startup remains visual-only.
- [ ] No new process execution without explicit approval.
- [ ] No new active network traffic without explicit approval.
- [ ] No mutating VPN, DNS, route, proxy, power, or system-setting behavior.
- [ ] Privacy docs updated if data collection changed.

## Validation

```sh
swift build
swift test
swift build -c release
git diff --check
```

## Compatibility Notes

Mention relevant Mac model, display setup, fullscreen behavior, or sleep/wake behavior.
