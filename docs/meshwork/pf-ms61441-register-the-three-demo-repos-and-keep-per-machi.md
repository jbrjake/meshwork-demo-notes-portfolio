---
id: pf-ms61441
title: Register the three demo repos and keep per-machine paths out of git
category: registry
seq: 10
verify: "all(contains repos.toml /meshwork-demo-notes-cli/, contains repos.toml /meshwork-demo-notes-sync/, contains repos.toml /meshwork-demo-notes-portfolio/, contains .gitignore /repos\\.local\\.toml/)"
status: doing
created: 2026-10-02T17:12Z
claimed-by: claude (602c381b-d7db-491e-8df6-85682e6152ed)
---
`repos.toml` registers meshwork-demo-notes-cli, meshwork-demo-notes-sync and this repo under their GitHub names, with https remotes. Registry names equal repo names, so cross-repo refs read `meshwork-demo-notes-sync#sy-…`.

A checkout defaults to `~/Documents/code/<name>`. A machine that keeps them elsewhere maps each name to its path under `[paths]` in `repos.local.toml`, which is gitignored. Sessions in any of the three repos export `MESHWORK_PORTFOLIO` pointing at this checkout, so their cross-repo refs resolve here.

## log
- 2026-10-02T17:12Z created
- 2026-10-02T17:12Z open→doing — claimed by claude (602c381b-d7db-491e-8df6-85682e6152ed)
