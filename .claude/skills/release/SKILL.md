---
name: release
description: Make a new release of Satellite Eyes. Use when asked to release, cut a release, ship, or publish a new version of Satellite Eyes.
---

# Release Satellite Eyes

Takes a new marketing version (e.g. `2.2.0`) and produces everything needed to
publish it. The only thing it commits is the version bump in this repo, which it
then tags. **Nothing is pushed, merged or made public** — the one thing it puts
on a server is a *draft* GitHub release, which only collaborators can see. The
final report hands pushing and publishing to the user.

If the user did not give a version number, ask for one before starting.

## Layout

Three sibling directories under `satellite-eyes/`:

| Path | Role | Git |
|------|------|-----|
| `app/` | this repo — the Xcode project | yes |
| `sparkle/` | staging area for the update feed: zips, release-note HTML, deltas, `appcast.xml`. Contents are uploaded to the `satellite-eyes` S3 bucket | no |
| `site/` | Middleman site for satelliteeyes.tomtaylor.co.uk | yes |

Use `$(git rev-parse --show-toplevel)` for the app root and `../sparkle`,
`../site` beside it. Put the `.xcarchive` and export directory in the session
scratchpad — never inside any of the three repos. `$SCRATCH` below stands for
that scratchpad path; substitute it, it is not an exported variable.

## How versioning works here

- `MARKETING_VERSION` in `Config/Shared.xcconfig` is the human version
  (`CFBundleShortVersionString`). Both of the target's configurations inherit
  that file, so it appears once.
- `CFBundleVersion` is *not* in the project. The "Update Build Number" script
  phase computes it at build time as `git rev-list HEAD | wc -l` + 1000, so it
  tracks the commit count (2.1.1 shipped as build 1221). Sparkle reads both
  values out of the built bundle, so nothing needs to be typed into the appcast
  by hand.
- That count is why the bump is committed *before* archiving: the bump commit
  itself increments it, so building after the commit is what makes the shipped
  build number equal to the one the tagged commit rebuilds to.

## Steps

### 1. Preflight

Report anything that fails and stop rather than working around it.

```bash
git -C . status --short                     # app repo: expect clean
git -C ../site status --short                # site repo: expect clean
git branch --show-current                    # expect main
grep -n "MARKETING_VERSION" Config/Shared.xcconfig                    # previous version
git tag --list <version>                     # expect empty — tag must not exist yet
command -v generate_appcast && ls ~/bin/BinaryDelta                   # Sparkle tools
security find-generic-password -a ed25519 -s https://sparkle-project.org >/dev/null && echo "signing key present"
gh auth status                               # GitHub CLI logged in
gh release view <version>                    # expect "release not found"
```

Never print the EdDSA key itself. Confirm the requested version is higher than
the current `MARKETING_VERSION`.

### 2. Bump the version and commit it

Edit the `MARKETING_VERSION = <old>` line in `Config/Shared.xcconfig` to the
new version, then commit just that file:

```bash
git add Config/Shared.xcconfig
git commit -m "Bump to <version>"
```

The commit must contain nothing but the bump. Do not push it.

If a later step fails and the release is abandoned, say so plainly: this commit
is already made, and unwinding it (`git reset --soft HEAD~1`) is the user's call.

### 3. Archive

A few minutes. The project builds clean, so investigate any new warning before
continuing.

```bash
xcodebuild -project SatelliteEyes.xcodeproj -scheme "Satellite Eyes" \
  -configuration Release -archivePath "$SCRATCH/satellite-eyes-<version>.xcarchive" \
  archive
```

The archived app is signed `Apple Development` at this point — that is correct;
the export in step 5 re-signs it with the Developer ID certificate.

### 4. Tag the release

Only after `** ARCHIVE SUCCEEDED **`. The tag goes on the version bump commit.

```bash
git tag -a <version> -m "<version>"
git tag -v <version>
```

- The tag name is the bare version — `2.2.0`, no `v` prefix — and the message is
  the same string, matching the `2.0.0` / `2.0.0-rc.1` tags.
- Tags must be signed. If signing fails, stop and report it — do not fall back
  to `--no-gpg-sign`.
- Do not push the tag.

### 5. Validate and notarize with Apple

`.claude/skills/release/assets/ExportOptions.plist` sets `method: developer-id`
and `destination: upload`, which is exactly Organizer's "Distribute App →
Direct Distribution": Apple validates the archive and the upload enters the
notary service.

```bash
xcodebuild -exportArchive \
  -archivePath "$SCRATCH/satellite-eyes-<version>.xcarchive" \
  -exportOptionsPlist .claude/skills/release/assets/ExportOptions.plist \
  -allowProvisioningUpdates
```

### 6. Export the notarized app

Waits for notarization to finish, then writes the app with the ticket stapled.

```bash
xcodebuild -exportNotarizedApp \
  -archivePath "$SCRATCH/satellite-eyes-<version>.xcarchive" \
  -exportPath "$SCRATCH/export"
```

### 7. Verify the exported bundle

All four must pass before the zip is built:

```bash
APP="$SCRATCH/export/Satellite Eyes.app"
plutil -p "$APP/Contents/Info.plist" | grep -E "CFBundleShortVersionString|CFBundleVersion"
codesign -dvv "$APP" 2>&1 | grep -E "Authority|Runtime"
xcrun stapler validate "$APP"
spctl -a -vvv -t exec "$APP"
```

Expect the new version number, a non-zero build number,
`Authority=Developer ID Application: Tom Taylor (UY2GK6B69X)`,
"The validate action worked!", and `accepted` /
`source=Notarized Developer ID`.

### 8. Zip into ../sparkle

The filename must be exactly `satellite-eyes-<version>.zip` — `generate_appcast`
pairs the zip with its release notes by basename, and the site links to this
name. `--keepParent` puts `Satellite Eyes.app` at the root of the archive.

```bash
ditto -c -k --sequesterRsrc --keepParent \
  "$SCRATCH/export/Satellite Eyes.app" \
  "../sparkle/satellite-eyes-<version>.zip"
```

### 9. Write the release notes

Create `../sparkle/satellite-eyes-<version>.html` from the changes since the
last release:

```bash
git log --oneline <previous-version>..HEAD
```

Format, matching `satellite-eyes-2.0.0.html` and `satellite-eyes-2.1.0.html`:

- An HTML **fragment** — no doctype, `<html>` or `<body>`. `generate_appcast`
  embeds fragments into the appcast as CDATA; a full document would instead be
  linked as an external file.
- A short intro `<p>`, then `<ul><li>` items. `<h2>` section headings ("New
  features!", "Bug fixes!") only for a release big enough to need them.
- User-facing and light in tone: what someone sees, not the commit list.
  Internal-only changes (project format upgrades, refactors, data pipeline
  work) collapse into one line or are omitted.
- Show the draft to the user before continuing — they usually want to
  reword it.

### 10. Rebuild the appcast XML

```bash
generate_appcast \
  --download-url-prefix https://satellite-eyes.s3.amazonaws.com/ \
  --link https://satelliteeyes.tomtaylor.co.uk/ \
  --major-version 1220 \
  ../sparkle
```

- `--major-version 1220` sets `sparkle:minimumAutoupdateVersion`. Keep it: 1220
  (2.1.0) was the first build with a working updater, so anything older — 2.0.0
  is 1211 — cannot auto-update and must be sent to the site to download by hand.
- The old zips must stay in `../sparkle` so deltas can be built against them.
  New `Satellite Eyes<new>-<old>.delta` files appear there.
- The feed keeps 3 versions per minimum-OS branch point by default, so the
  oldest macOS 13 item is dropped and its zip moved to `../sparkle/old_updates/`
  (1.5.0 survives separately — it requires 10.12). Files already on S3 are not
  deleted there, so old direct links keep working. Say in the report which files
  moved.
- Verify: the new `<item>` is first, with the right `shortVersionString`,
  `sparkle:version`, `edSignature`, an `enclosure` length matching the zip, and
  the release notes inlined as CDATA.

### 11. Draft the GitHub release

Create the release on `tomtaylor/satellite-eyes` as a draft, with the same
notes and zip as the appcast. Use the final, approved notes from step 9.

```bash
gh api repos/tomtaylor/satellite-eyes/releases \
  -f tag_name=<version> \
  -f name="Satellite Eyes <version>" \
  -F draft=true \
  -F body=@"../sparkle/satellite-eyes-<version>.html" \
  --jq .html_url
gh release upload <version> "../sparkle/satellite-eyes-<version>.zip"
gh release view <version>
```

- Don't use `gh release create`. It refuses a tag that exists locally but not on
  the remote, even with `--draft`, and its `--target` workaround would make
  GitHub create a new tag. The API call creates the draft without touching tags.
- A draft's URL is `…/releases/tag/untagged-<hash>` until it is published. That
  is expected.
- The title and the HTML-fragment body match the published `2.0.0` release.
  GitHub renders the HTML as-is, so the notes file needs no Markdown version.
- It **must** be a draft. The tag has not been pushed yet. Publishing now would
  make GitHub create its own unsigned tag at `origin/main`, which does not
  contain the bump commit, and pushing the real tag would then be rejected.
  GitHub does not create the tag for a draft, so the draft is safe.
- Verify the release shows `draft: true`, the `<version>` tag, and the single
  asset `satellite-eyes-<version>.zip`.
- If the notes change after this, update both copies: rerun `generate_appcast`
  (see Troubleshooting) and
  `gh release edit <version> --notes-file "../sparkle/satellite-eyes-<version>.html"`.
- If the release is abandoned, say the draft exists. Deleting it
  (`gh release delete <version>`) is the user's call, as with the bump commit.

### 12. Update the site

In `../site/source/index.html.erb`, update the single download line — zip URL,
version, and today's release date in the existing `7th August 2026` ordinal
style:

```html
<a href="https://satellite-eyes.s3.amazonaws.com/satellite-eyes-<version>.zip" rel="external">Download version <version></a> (released <date>)
```

Nothing else on the site references the version. Don't run the Middleman build
or touch `build/`; past release commits changed only `source/index.html.erb`.

### 13. Report and stop

Do not push, merge, upload or publish. Summarise:

- New/changed files in `../sparkle` (zip + size, html, appcast.xml, deltas, anything
  moved to `old_updates/`), and the verified version / build number.
- The bump commit and signed tag from steps 2 and 4, both unpushed, and the
  still-uncommitted `source/index.html.erb` edit in `site`.
- The draft GitHub release URL from step 11.
- What is left for the user, in this order:
  1. Push `main` and the tag (`git push origin main <version>`).
  2. Publish the GitHub release (`gh release edit <version> --draft=false`).
     This must come after the tag push, for the reason given in step 11.
  3. Commit the site change (`Release <version>`) and deploy it.
  4. Upload the `../sparkle` contents (zips, deltas, `appcast.xml` and the
     release-note HTML) to the `satellite-eyes` S3 bucket.

  The Homebrew cask is updated upstream and is not part of this process.

## Troubleshooting

- **Notarization rejected** — `xcrun notarytool log <submission-id>` explains
  why. The usual causes are a missing hardened runtime or an unsigned nested
  binary; both would be a regression in the project settings. The tag already
  exists at this point, so it now points at a commit that never shipped: report
  that, and let the user choose between fixing forward under the same version
  (`git tag -d <version>`, then re-archive and re-tag) and moving to the next
  patch version.
- **Upload can't authenticate** — `destination: upload` uses the Apple ID
  configured in Xcode's accounts. If it fails, tell the user rather than
  inventing credentials; the fallback is Organizer, or an App Store Connect API
  key passed via `-authenticationKeyPath`, `-authenticationKeyID` and
  `-authenticationKeyIssuerID`.
- **`generate_appcast` can't sign** — the private EdDSA key is missing from the
  login keychain (service `https://sparkle-project.org`, account `ed25519`).
  Stop; it must not be regenerated, as `SUPublicEDKey` in
  `SatelliteEyes-Info.plist` pins the existing key and shipped copies verify
  against it.
- **Re-running after hand-editing `appcast.xml` or a release-note file** — the
  signatures cover those files, so `generate_appcast` has to be run again
  afterwards.
