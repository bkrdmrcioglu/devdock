# DevDock site

Source for <https://bkrdmrcioglu.github.io/devdock/>, served by GitHub Pages from
`main` → `/docs`.

`index.html` is self-contained — styles are inline, the only external files are the
images in `assets/`. Edit it directly and push to `main`; Pages rebuilds on its own.

Keep these in sync when cutting a release:

- Homebrew command matches [`Casks/devdock.rb`](../Casks/devdock.rb)
- Feature list matches the [root README](../README.md)
- Download button points at `releases/latest`, so it needs no version bump
