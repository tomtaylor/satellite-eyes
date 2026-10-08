---
name: release
description: Make a new release of Satellite Eyes. Use when asked to release, cut a release, ship, or publish a new version of Satellite Eyes.
---

# Release Satellite Eyes

Takes a new marketing version (e.g. `2.2.0`) and builds everything needed to
publish it: a notarized zip, release notes, the Sparkle appcast and the site
download link. Then it **asks for explicit approval** before publishing anything.
Publishing means pushing to GitHub, uploading to S3 and creating the GitHub
release.

Until that approval, the only changes are local: the version bump commit and
its tag in this repo, the files in `../sparkle` and an uncommitted edit in
`../site`.

If the user did not give a version number, ask for one before starting.

## Layout

Three sibling directories under `satellite-eyes/`:

| Path | Role | Git |
|------|------|-----|
| `app/` | this repo — the Xcode project | yes, `main` |
| `sparkle/` | staging area for the update feed: zips, release-note HTML, deltas, `appcast.xml`. The `satellite-eyes` S3 bucket mirrors it exactly | no |
| `site/` | Middleman site for satelliteeyes.tomtaylor.co.uk. Pushing `master` deploys it | yes, `master` |

Run commands from the app root, with `../sparkle` and `../site` beside it.
Build products go in `/tmp/satellite-eyes-<version>`, never inside any of the
three directories.

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
  build number equal to the one the tagged commit rebuilds to. For the same
  reason, make no other commits in this repo until the tag is on the bump commit.

## Steps

### 1. Preflight

Report anything that fails and stop rather than working around it.

```bash
git status --short -- . ':!.claude'          # app repo: expect clean outside .claude/
git -C ../site status --short                # site repo: expect clean
git branch --show-current                    # expect main
grep -n "MARKETING_VERSION" Config/Shared.xcconfig                    # previous version
git tag --list <version>                     # expect empty — tag must not exist yet
command -v generate_appcast && ls ~/bin/BinaryDelta                   # Sparkle tools
security find-generic-password -a ed25519 -s https://sparkle-project.org >/dev/null && echo "signing key present"
gh auth status                               # GitHub CLI logged in
gh release view <version>                    # expect "release not found"
aws sts get-caller-identity >/dev/null && echo "aws credentials present"
```

Uncommitted changes under `.claude/` are allowed. They don't affect the build,
and the bump commit only adds `Config/Shared.xcconfig`. Never print the EdDSA
key itself. Confirm the requested version is higher than the current
`MARKETING_VERSION`.

### 2. Bump the version and commit it

Edit the `MARKETING_VERSION = <old>` line in `Config/Shared.xcconfig` to the
new version, then commit just that file:

```bash
git add Config/Shared.xcconfig
git commit -m "Bump to <version>"
```

The commit must contain nothing but the bump.

If a later step fails and the release is abandoned, say so plainly: this commit
is already made, and unwinding it (`git reset --soft HEAD~1`) is the user's call.

### 3. Build, notarize, verify and zip

Start the build script in the background. It takes a few minutes, and the
release notes (step 4) are written while it runs.

```bash
.claude/skills/release/assets/build.sh <version>
```

The script stops at the first failure and prints the tail of the log that
failed. The logs are in `/tmp/satellite-eyes-<version>/`. It does the
following:

1. Archives the Release build. Any compiler warning fails the build, apart from
   the harmless AppIntents "Metadata extraction skipped" line. The project
   builds clean, so a new warning needs investigating.
2. Exports with `assets/ExportOptions.plist` (`method: developer-id`,
   `destination: upload`). This is Organizer's "Distribute App → Direct
   Distribution": Apple validates the archive and submits it for notarization.
   The archive is signed `Apple Development` until this re-signs it with the
   Developer ID certificate.
3. Runs `-exportNotarizedApp` every 30 seconds until Apple finishes, for up to
   20 minutes. Until then it fails with "is processing and not ready for
   distribution" rather than waiting. It usually takes a minute or two.
4. Checks the exported app: the bundle version matches, the build number is
   valid, it is signed by `Developer ID Application: Tom Taylor (UY2GK6B69X)`
   with the hardened runtime, `stapler validate` passes, and `spctl` accepts it
   as `Notarized Developer ID`.
5. Zips it to `../sparkle/satellite-eyes-<version>.zip` with `ditto --keepParent`,
   so `Satellite Eyes.app` is at the root of the zip. `generate_appcast` matches
   the zip to its notes by filename, and the site links to it.

It finishes by printing the version, build number and zip size.

### 4. Write the release notes (while step 3 runs)

Create `../sparkle/satellite-eyes-<version>.html` from the changes since the
last release:

```bash
git log <previous-version>..HEAD
```

Format, matching the earlier `satellite-eyes-*.html` files:

- An HTML **fragment** — no doctype, `<html>` or `<body>`. `generate_appcast`
  embeds fragments into the appcast as CDATA; a full document would instead be
  linked as an external file.
- A short intro `<p>`, then `<ul><li>` items. `<h2>` section headings ("New
  features!", "Bug fixes!") only for a release big enough to need them.
- User-facing and light in tone: what someone sees, not the commit list.
  Internal-only changes (project format upgrades, refactors, data pipeline
  work) collapse into one line or are omitted.
- Show the draft to the user — they usually want to reword it. The appcast
  (step 6) waits for their approval, because it signs the notes.

### 5. Tag the release

Only after `build.sh` succeeds. The tag goes on the version bump commit, which
is still `HEAD`.

```bash
git tag -a <version> -m "<version>"
git tag -v <version>
```

- The tag name is the bare version — `2.2.0`, no `v` prefix — and the message is
  the same string, matching the earlier tags.
- Tags must be signed (SSH, via `tag.gpgSign`). `git tag -v` should report a
  "Good "git" signature". If signing fails, stop and report it. Don't fall back
  to `--no-gpg-sign`.

Tagging only after the build passes means a failed build leaves no tag to clean
up.

### 6. Rebuild the appcast XML

Only once the user has approved the notes.

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
  oldest macOS 13 item is dropped (1.5.0 survives separately — it requires
  10.12). Some of that version's files may be moved to `../sparkle/old_updates/`.
  In 2.2.0 only its deltas moved and its zip stayed. Because the S3 sync uses
  `--delete`, moved files also move in the bucket, so their old URLs stop
  working. Say in the report which version left the feed and which files moved.
- Check the new item:

  ```bash
  awk '/<item>/{n++} n==1' ../sparkle/appcast.xml | sed '/<\/item>/q' \
    | grep -oE '<sparkle:(shortVersionString|version)>[^<]*|enclosure url="[^"]*satellite-eyes-[^"]*" length="[0-9]+"|edSignature="|CDATA'
  stat -f %z ../sparkle/satellite-eyes-<version>.zip
  ```

  Expect the new version and build number, a zip enclosure whose `length`
  matches the `stat` size, at least one `edSignature`, and `CDATA` (the notes
  are inlined).

### 7. Update the site

In `../site/source/index.html.erb`, update the single download line: the zip
URL, the version, and today's release date in the existing `8th October 2026`
style. Leave the markup around them alone:

```html
<a class="download" href="https://satellite-eyes.s3.amazonaws.com/satellite-eyes-<version>.zip" rel="external">Download version <version></a> <span class="release-date">(released <date>)</span>
```

Nothing else on the site references the version. Don't run the Middleman build
or touch `build/`. Past release commits changed only `source/index.html.erb`.
Don't commit yet.

### 8. Report, then ask before publishing

Summarise what has been built:

- The verified version and build number, and the zip and its size.
- New/changed files in `../sparkle`: the HTML, `appcast.xml`, the deltas, which
  version left the feed and which files moved to `old_updates/`.
- The bump commit and signed tag (both local), and the uncommitted site edit.
- The release notes as they will appear.

Then show the exact publishing commands from step 9 and **ask the user for
explicit approval**. Do not run any of step 9 until the user replies approving
it, in a message sent after this request. These do not count as approval:
earlier messages, approval given for a previous release, task notifications,
and anything you said yourself. The user may approve only some of the commands;
run just those, and list the rest as theirs to do. If they decline, stop there
and give them the step 9 commands to run themselves.

### 9. Publish (only after approval)

Run these in this order, and stop at the first failure. Each step depends on
the ones before it.

```bash
# 1. App commit and signed tag. Push main by name, whichever branch is checked out.
git push origin main <version>

# 2. Sparkle files. Upload everything except the appcast first, so the live
#    feed never points at a zip that is not there yet, then sync again to
#    upload the appcast. --delete makes the bucket an exact copy of ../sparkle.
aws s3 sync --acl public-read --delete --exclude .DS_Store --exclude appcast.xml ../sparkle/ s3://satellite-eyes/
aws s3 sync --acl public-read --delete --exclude .DS_Store ../sparkle/ s3://satellite-eyes/

# 3. GitHub release, published, with the same notes and zip. The tag is
#    already pushed, so --verify-tag uses it rather than creating one.
gh release create <version> "../sparkle/satellite-eyes-<version>.zip" \
  --verify-tag \
  --title "Satellite Eyes <version>" \
  --notes-file "../sparkle/satellite-eyes-<version>.html"

# 4. Site. Pushing master deploys it, so this goes last, once the zip is live.
git -C ../site add source/index.html.erb
git -C ../site commit -m "Release <version>"
git -C ../site push origin master
```

- The bucket's objects are public through per-object ACLs, so `--acl
  public-read` is required. Without it the files upload but can't be
  downloaded.
- The GitHub release title and HTML-fragment body match the earlier releases.
  GitHub renders the HTML as it is.
- Afterwards, check that it's live:

  ```bash
  curl -sI https://satellite-eyes.s3.amazonaws.com/satellite-eyes-<version>.zip | head -1   # 200
  curl -s https://satellite-eyes.s3.amazonaws.com/appcast.xml | grep -c "<sparkle:shortVersionString><version>"  # 1
  gh release view <version> --json isDraft,assets --jq '.isDraft, .assets[].name'
  ```

Report the GitHub release URL. The Homebrew cask is updated upstream and is not
part of this process.

## Troubleshooting

- **Notarization rejected** — `build.sh` fails at the notarized export.
  `xcrun notarytool history` lists recent submissions, and `xcrun notarytool log
  <submission-id>` explains the rejection. The usual causes are a missing
  hardened runtime or an unsigned nested binary; both would be a regression in
  the project settings. No tag exists yet. Once it's fixed, the bump commit is
  no longer the last commit: either move the fix before it (the user's call), or
  release the next patch version from a new bump.
- **Upload can't authenticate** — `destination: upload` uses the Apple ID
  configured in Xcode's accounts. If it fails, tell the user rather than
  inventing credentials; the fallback is Organizer, or an App Store Connect API
  key passed via `-authenticationKeyPath`, `-authenticationKeyID` and
  `-authenticationKeyIssuerID`.
- **`build.sh` says the zip already exists** — a previous run got that far.
  Check whether that zip is from this same commit before deleting it; never
  overwrite a zip that has already been uploaded.
- **`generate_appcast` can't sign** — the private EdDSA key is missing from the
  login keychain (service `https://sparkle-project.org`, account `ed25519`).
  Stop; it must not be regenerated, as `SUPublicEDKey` in
  `SatelliteEyes-Info.plist` pins the existing key and shipped copies verify
  against it.
- **Re-running after hand-editing `appcast.xml` or a release-note file** — the
  signatures cover those files, so `generate_appcast` has to be run again
  afterwards. If the GitHub release already exists, update its notes too:
  `gh release edit <version> --notes-file "../sparkle/satellite-eyes-<version>.html"`.
