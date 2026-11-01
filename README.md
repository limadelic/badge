# badge

## Prune

`.github/workflows/prune.yml` is a reusable workflow. It drops the badges of a closed PR or a deleted branch from the store branch, redeploys Pages, and strips the badge block from the PR body.

```yaml
on:
  pull_request:
    types: [closed]
  delete:

jobs:
  prune:
    permissions:
      contents: write
      pages: write
      id-token: write
      pull-requests: write
    uses: limadelic/badge/.github/workflows/prune.yml@v1
```

Permissions: `contents: write` pushes the store branch, `pages: write` and `id-token: write` deploy Pages, `pull-requests: write` patches the PR body.
