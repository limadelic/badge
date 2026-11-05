set -euo pipefail

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

for attempt in 1 2 3 4 5; do
  git fetch -q origin main
  git switch -q -C main FETCH_HEAD
  ruby "$ACTION_PATH/../lib/body.rb"
  git diff --quiet -- README.md && exit 0
  git add README.md
  git commit -qm "Add badges [skip ci]"
  git push -q origin HEAD:main && exit 0
done
exit 1
