# Tasks: OSC 52 Clipboard Support

## 1. Base Image Updates

- [x] 1.1 Create `/usr/local/bin/osc52-copy` script in `dockerfiles/base/Dockerfile`.
- [x] 1.2 Make it executable.
- [x] 1.3 Create a symlink `/usr/local/bin/pbcopy` -> `/usr/local/bin/osc52-copy`.

## 2. Verification

- [ ] 2.1 Verify `osc52-copy` script content is correct (handles base64 wrapping).
- [ ] 2.2 Verify `pbcopy` command exists in the image.
