# badge

A reusable CI badge unit. A project makes one badge per label in its test job, then calls one reusable workflow, `badge.yml`, once.

## Setup

1. Settings → Pages → Source: GitHub Actions.
2. Settings → Environments → `github-pages` → Deployment branches and tags: choose "Selected branches and tags", then add `main`, `*`, `*/merge` and `refs/pull/*/merge`, so PR merge refs can deploy. With gh, one command per name. `OWNER/REPO` is a placeholder: replace it with your owner and repo.

   ```sh
   gh api -X POST repos/OWNER/REPO/environments/github-pages/deployment-branch-policies -f name='main' -f type=branch
   gh api -X POST repos/OWNER/REPO/environments/github-pages/deployment-branch-policies -f name='*' -f type=branch
   gh api -X POST repos/OWNER/REPO/environments/github-pages/deployment-branch-policies -f name='*/merge' -f type=branch
   gh api -X POST repos/OWNER/REPO/environments/github-pages/deployment-branch-policies -f name='refs/pull/*/merge' -f type=branch
   ```

3. Caller job: see Use. It needs `uses: limadelic/badge/.github/workflows/badge.yml@v1.1` and `contents`, `pages`, `id-token` and `pull-requests` write permissions.

## Use

```yaml
name: CI

on:
  push:
    branches-ignore: [badges]
  pull_request:
    types: [opened, reopened, synchronize, closed]
  delete:

permissions:
  contents: write
  pages: write
  id-token: write
  pull-requests: write

jobs:
  test:
    if: github.event_name != 'delete' && github.event.action != 'closed'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: "3.3"
          bundler-cache: true

      - run: bundle exec cucumber

      - id: cukes
        if: ${{ !cancelled() }}
        uses: limadelic/badge/cukes@v1.1
        with:
          json: cucumber.json

      - if: ${{ !cancelled() }}
        uses: limadelic/badge/make@v1.1
        with:
          label: cukes
          message: ${{ steps.cukes.outputs.message }}
          color: ${{ steps.cukes.outputs.color }}
          logo: cucumber
          files: cucumber.json

  badges:
    needs: [test]
    if: ${{ !cancelled() }}
    permissions:
      contents: write
      pages: write
      id-token: write
      pull-requests: write
    uses: limadelic/badge/.github/workflows/badge.yml@v1.1
    with:
      labels: cukes=cucumber.json
```

One `make` step per badge goes in the test job. `labels` has one line per badge, `label=linkfile`; the linkfile is what the badge links to and defaults to `badge.json`.

`if: !cancelled()` keeps the badges running after a red test run, so the badge shows red. Closed pull requests and deleted branches skip the test job, and the call still runs to prune.

The caller job must grant `contents`, `pages`, `id-token` and `pull-requests` write.

## Inputs

`badge.yml`:

| Input    | Default  | Does                                      |
| -------- | -------- | ----------------------------------------- |
| `labels` | required | one `label=linkfile` per line             |
| `branch` | `badges` | store branch for the badge json and files |

## What runs

On push and pull request (opened, synchronize):

1. `body`: writes the badge block into the open PR body, only when missing.
2. `site`: merges every `badge-*` artifact into the store branch, pushes it, deploys Pages. Pages runs one deploy at a time.
3. `body_after_site`: rewrites the PR body block, now with a cache-busted link.
4. `readme`: on push to `main` only, writes the main badge block into `README.md` and pushes it.
5. `check`: runs only when `site` succeeds. Retries up to 10 times, 15 seconds apart. Fails if a badge json or svg is missing or wrong, if a PR body with a badge block or the README has no badge image, or if the store holds a stale dir.

On closed pull request (same repo) and branch delete: `prune` drops the prefix from the store branch, redeploys Pages, and strips the block from the PR body.

The unit's own scripts run from a checkout of this repo at the same commit that `badge.yml` came from.

## Parts

| Part        | Kind              | Does                                                     |
| ----------- | ----------------- | -------------------------------------------------------- |
| `prefix`    | composite action  | `main/` on main, the PR number on a PR, else the branch  |
| `cukes`     | composite action  | `n/total` message and color from a cucumber json         |
| `make`      | composite action  | writes the badge json and files, uploads `badge-<label>` |
| `body`      | composite action  | writes the PR body block, or the README block on main    |
| `badge.yml` | reusable workflow | the whole flow above                                     |

## Tests

```sh
bundle exec rubocop && ruby -Ilib -e 'Dir["test/*_test.rb"].each { |f| require "./#{f}" }'
```
