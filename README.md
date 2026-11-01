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

3. Caller job: see Use. It needs `uses: limadelic/badge/.github/workflows/badge.yml@v1.2` and `contents`, `pages`, `id-token` and `pull-requests` write permissions and `actions` read.

## Use

```yaml
name: CI

on:
  push:
    branches: ["**"]
  pull_request:
    types: [opened, reopened, synchronize, closed]
  delete:

permissions:
  contents: write
  actions: read
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
        uses: limadelic/badge/cukes@v1.2
        with:
          json: cucumber.json

      - if: ${{ !cancelled() }}
        uses: limadelic/badge/make@v1.2
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
      actions: read
      pages: write
      id-token: write
      pull-requests: write
    uses: limadelic/badge/.github/workflows/badge.yml@v1.2
    with:
      labels: cukes=cucumber.json
```

One `make` step per badge goes in the test job. `labels` has one line per badge, `label=linkfile`; the linkfile is what the badge links to and defaults to `badge.json`.

`make`'s `files` takes files and dirs, space separated. A dir is copied recursively under its own name, so `files: cover` puts `cover/index.html` at `<prefix><label>/cover/index.html`. `link` names a file in the label dir, a path into a copied dir such as `cover/index.html`, or a full `http(s)://` URL that is kept as given. A file path must exist after the copy. `link` defaults to the first plain file in `files`, else `badge.json`.

`if: !cancelled()` keeps the badges running after a red test run, so the badge shows red. Closed pull requests and deleted branches skip the test job, and the call still runs to prune.

The caller job must grant `contents`, `pages`, `id-token` and `pull-requests` write, and `actions` read.

## Inputs

`badge.yml`:

| Input    | Default  | Does                          |
| -------- | -------- | ----------------------------- |
| `labels` | required | one `label=linkfile` per line |

`make` takes optional `label-color` and `logo-color`. Each is written to `badge.json` as shields `labelColor` and `logoColor`. When not given, the key is left out.

## What runs

On push and pull request (opened, synchronize):

1. `body`: writes the badge block into the open PR body, only when missing.
2. `site`: restores the last Pages deploy from its artifact, merges every `badge-*` artifact into it, uploads it (kept 90 days) and deploys Pages. Pages runs one deploy at a time.
3. `body_after_site`: rewrites the PR body block, now with a cache-busted link.
4. `readme`: on push to `main` only, writes the main badge block into `README.md` and pushes it.
5. `check`: runs only when `site` succeeds. Restores the last Pages deploy and reads its prefix dirs from `_site`. Retries up to 10 times, 15 seconds apart. Fails if the store is empty, if a push to `main` finds no `main/` prefix, if a badge json or svg is missing or wrong, if a PR body with a badge block or the README has no badge image, or if the store holds a stale dir.

On closed pull request (same repo) and branch delete: `prune` restores the last Pages deploy, drops the prefix from it, redeploys Pages (kept 90 days), and strips the block from the PR body.

The unit's own scripts run from a checkout of this repo at the same commit that `badge.yml` came from.

## Parts

| Part        | Kind              | Does                                                     |
| ----------- | ----------------- | -------------------------------------------------------- |
| `prefix`    | composite action  | `main/` on main, the PR number on a PR, else the branch  |
| `restore`   | composite action  | restores the last Pages deploy into `_site`              |
| `cukes`     | composite action  | `n/total` message and color from a cucumber json         |
| `make`      | composite action  | writes the badge json and files, uploads `badge-<label>` |
| `body`      | composite action  | writes the PR body block, or the README block on main    |
| `badge.yml` | reusable workflow | the whole flow above                                     |

## Tests

```sh
bundle exec rubocop && ruby -Ilib -e 'Dir["test/*_test.rb"].each { |f| require "./#{f}" }'
```
