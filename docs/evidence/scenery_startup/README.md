# Graphical client startup — 18 October 2026

Actual macOS OpenGL captures from an updated main client connected over local
ENet to the separate headless-server implementation. Godot 4.7.2, Dummy audio,
voice off. Normal lighting, rain and normal seed 13 van/boat objectives.
Enemies were frozen after loading; boat parts and survivor positions were staged,
and extraction time was advanced. This is not an ordinary uninterrupted playthrough.

- [Camp after joining](client_0_joined.png)
- [Boatyard after installing parts](client_0_boat_fitted.png)
- [Real process results](woods_1_summary.json): 26 server and 10 graphical client
  assertions, two rounds, clean exits and no engine warnings/errors.

The test driver lives on headless-server (`tools/verify_dedicated.py`), with this
main worktree selected using `--client-path` and `--graphical-clients`.
The client uses normal navigation and rendering. No headless scenery suppression
is applied to these graphical captures. The server matches ENet's peer timeout
to its existing 90-second loading allowance.

`tests/integration/pixel_palette.gd` compares 1,768 resized pixels across eight
seeded images with the former exhaustive weighted palette search: zero differences.
Required main import and startup checks passed without errors or warnings.
This evidence does not establish remote-network latency or performance on other PCs.
