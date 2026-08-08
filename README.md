# CI iOS build number

Unprotected counter branch used by `deploy.yml` / `testflight.yml`.

- `BUILD_NUMBER` is the last allocated CI build (source of truth for Firebase / TestFlight).
- Do **not** add branch protection here — `GITHUB_TOKEN` must be able to push.
- Do **not** merge this branch into `main`.
