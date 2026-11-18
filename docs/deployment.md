# Deployment

`.github/workflows/deploy-itch.yml` runs the smoke test and a headless Web export (Godot 4.7.2,
Web templates only) on every pull request and push to `main`. Pull requests also upload the web
build as a downloadable artifact.

On `main` (or a manual run from the Actions tab) it then pushes `build/web` to itch.io with
butler, to the `hiimdamien/dungeon-duels:html5` channel, using the `BUTLER_API_KEY` repository
secret. A failing smoke test blocks the deploy.

To export locally the same way:

```bash
godot --headless --export-release "Web" build/web/index.html
```

`build/` is gitignored.
