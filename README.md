# One Command Install

```
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply anthonycastiglione
```

# When you forget how to tell Neovim about a new global ruby version
Edit ~/.tool-versions and give it the new version! The internal tooling respects that file not the version in `.ruby_version` in a repo or the `asdf set` one!
