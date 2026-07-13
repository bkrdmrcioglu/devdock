# DevDock marketing site

Public landing lives in a **separate** repo so the Swift source can stay private:

**https://github.com/bkrdmrcioglu/devdock-site**  
**Live:** https://bkrdmrcioglu.github.io/devdock-site/

This `docs/` folder is the source copy inside the private app repo. Edit here, then sync to `devdock-site`.

## Sync to public Pages

```bash
# from DevDock root
rsync -a --delete \
  --exclude README.md \
  --exclude LEMON.md \
  docs/ /tmp/devdock-site-sync/

# in the clone of bkrdmrcioglu/devdock-site:
# copy those files to repo root, commit, push
```

Or push from a fresh folder (done by the release agent once):

```bash
mkdir -p /tmp/devdock-site && cd /tmp/devdock-site
# copy index.html styles.css assets/
git init
git remote add origin https://github.com/bkrdmrcioglu/devdock-site.git
```

## Enable Pages (one-time)

1. Open https://github.com/bkrdmrcioglu/devdock-site/settings/pages  
2. Source: **Deploy from a branch**  
3. Branch: `main` · Folder: `/` (root)  
4. Save

## Local preview

```bash
cd docs
python3 -m http.server 8080
# http://127.0.0.1:8080
```

## Lemon Squeezy “Your website”

Use: `https://bkrdmrcioglu.github.io/devdock-site/`

## Free download binary

App zip (not source) is published on the public site repo Releases:

https://github.com/bkrdmrcioglu/devdock-site/releases/download/v0.2.0/DevDock-0.2.0.zip

After `./scripts/release.sh`, upload the new zip:

```bash
gh release create vX.Y.Z dist/DevDock-X.Y.Z.zip --repo bkrdmrcioglu/devdock-site --title "DevDock X.Y.Z"
```

Then update download links in `docs/index.html` and sync the site.
