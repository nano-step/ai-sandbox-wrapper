# [change-type]: <short title>

<!-- Labels: lane:?, change-type:?, status:in-progress -->

## Summary

<!-- 1-3 sentences. What changes and why. -->

## Lane

- [ ] tiny — docs/typo/config only
- [ ] normal — feature or fix
- [ ] high-risk — hard gate touched (explain which gate below)

**Hard gate triggered** (if high-risk): <!-- Docker security / SSH / network / container perms -->

## Acceptance criteria

<!-- Concrete, testable. One per line. -->
- [ ] 
- [ ] 

## Validation

### Quick validate
```bash
bash -n lib/*.sh && npm test
```
- [ ] Passes

### User-flow test (normal + high-risk only)
```bash
# Replace {tool} with the relevant tool name
docker run --rm ai-{tool}:latest {tool} --version
```
- [ ] Passes

### High-risk extra (high-risk only)
- [ ] CAP_DROP=ALL present in any new/modified Dockerfile
- [ ] No host home directory mounts added
- [ ] Security diff reviewed manually
- [ ] Second maintainer sign-off obtained

## OpenSpec change name

<!-- Leave blank for tiny lane -->
`openspec/<change-name>`

## Evidence

<!-- Link to docs/evidence/ artifacts after completion -->

## Notes

<!-- Decisions, tradeoffs, links to related issues/PRs -->
