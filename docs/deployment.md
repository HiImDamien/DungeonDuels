# Deployment

`.github/workflows/deploy-itch.yml` runs the smoke test and a headless Web export (Godot 4.7.2,
Web templates only) on every pull request and push to `main`. Pull requests also upload the web
build as a downloadable artifact.

Merging to `main` does **not** publish anything. Releases are batched: several issues land on
`main`, and when they're worth an itch update, push a version tag. The easiest way is a GitHub
release, which creates the tag and writes notes listing every PR merged since the last release
(useful as an itch devlog):

```bash
gh release create v0.4.0 --generate-notes -R HiImDamien/DungeonDuels
```

A `v*` tag (or a manual run from the Actions tab) pushes `build/web` to itch.io with butler, to
the `hiimdamien/dungeon-duels:html5` channel, using the `BUTLER_API_KEY` repository secret. A tag
release shows on itch as its tag name (`v0.4.0`), and a manual run as `<date>-<sha>`. A failing
smoke test blocks the deploy.

Versions follow `vMAJOR.MINOR.PATCH`: bump PATCH for fixes only, MINOR when a release adds
features.

To export locally the same way:

```bash
godot --headless --export-release "Web" build/web/index.html
```

`build/` is gitignored.
