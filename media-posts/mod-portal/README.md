# Mod Portal

Everything needed to publish each mod on <https://mods.factorio.com>:

- `<mod>/portal.md`: the summary, category, tags, license, links, and the Markdown description to paste.
- `<mod>/gallery/`: screenshots for the gallery, uploaded in file-name order.
- `../../<mod>/thumbnail.png`: the 144x144 mod thumbnail in the repository's mod root, packaged in the zip and also uploaded on the portal.

`make-assets.sh` regenerates the thumbnails and the gallery from the demo-video recordings in the git-ignored `../video-demo-output/` (`media-posts/video-demo-output/` from the repository root).

## Publishing a release

Run these release steps from the repository root:

1. Bump `version` in `<mod>/info.json` and add a matching entry at the top of `<mod>/changelog.txt` (the format is strict: a line of 99 dashes, `Version:`, `Date:`, two-space category lines, four-space `- ` entries).
2. Run `./tests/run-prototype-tests.sh`, then `./make.sh <mod>`; the zip is written to the Factorio mods folder.
3. First release: on the portal choose "Upload new mod", upload the zip, then fill in the fields from `portal.md` and upload the gallery. Publish Space Lab before Warp Drive, which lists it as an optional dependency.
4. Later releases: open the mod page, "Edit", "Upload new version", and upload the zip.
