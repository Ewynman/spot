# CI iOS build number

Unprotected counter branch used by `deploy.yml` / `testflight.yml`.

- `BUILD_NUMBER` is the last allocated CI build (source of truth for Firebase / TestFlight).
- Do **not** add branch protection here — `GITHUB_TOKEN` must be able to push.
- Do **not** merge this branch into `main`.

Advance manually if needed:

```bash
git fetch origin ci/build-number
git show origin/ci/build-number:BUILD_NUMBER
# then push a commit that sets BUILD_NUMBER ahead of the highest shipped build
```
