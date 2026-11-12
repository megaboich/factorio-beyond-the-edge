# Media Posts

Publishing copy, campaign images, and demo-video sources for Beyond the Edge. This directory is outside every mod root and is never packaged with a mod.

| Directory | Contents |
| --- | --- |
| [forum-post/](forum-post/post.md) | Factorio forum post in BBCode, screenshot previews, and video thumbnails |
| [reddit-post/](reddit-post/post.md) | Reddit post text, screenshots, and ignored video uploads |
| [mod-portal/](mod-portal/README.md) | Mod Portal descriptions, gallery images, and thumbnail/gallery generator |
| [video-demo/](video-demo/README.md) | YouTube descriptions, narration, subtitles, recording helpers, and editing scripts |
| `video-demo-output/` | Git-ignored recordings, masters, audio, and intermediate generated video assets; created when needed |

Run the portal asset generator from the repository root:

```sh
./media-posts/mod-portal/make-assets.sh
```

It reads `media-posts/video-demo-output/`, writes galleries under `media-posts/mod-portal/`, and still writes packaged thumbnails to the actual `spacelab/` and `warp-drive/` mod roots. Video scripts resolve their inputs and outputs relative to their own location; see the [video workflow](video-demo/README.md).

The forum source uses raw GitHub image URLs under `media-posts/`. After publishing this directory move, update those URLs in the already-published forum post too: GitHub does not redirect raw image links from the former root-level folders. Editing the local source does not update a live post.
