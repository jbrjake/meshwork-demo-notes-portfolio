---
id: pf-wdyw884
title: "Say in the README what the three repos are, that the sessions are staged, and how to replay them"
category: story
seq: 70
needs: [pf-2fkwhgm]
verify: "all(exists README.md, contains README.md /story\\/replay\\.sh/)"
status: done
created: 2026-10-02T17:12Z
---
The README names the three repos and the story they tell. It says the sessions are staged by a script, that every command and output in the history is real, and how to run `story/replay.sh`.

## log
- 2026-10-02T17:12Z created
- 2026-10-02T17:54Z open→doing — claimed by claude (602c381b-d7db-491e-8df6-85682e6152ed)
- 2026-10-02T17:54Z doing→done — verify exit 0 @ afba5d7+1
