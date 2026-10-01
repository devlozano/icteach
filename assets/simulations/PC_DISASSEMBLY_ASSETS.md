# PC disassembly assets and interaction

The workbench reuses the exact assembly kit so hardware stays visually consistent:
- pc-case-workbench-realistic.png: empty chassis, revealed progressively.
- assembly-motherboard-matched.png, assembly-cpu-matched.png,
  assembly-cooler-matched.png, assembly-ram-ddr4-matched.png,
  assembly-gpu-matched.png, assembly-ssd-matched.png,
  assembly-psu-matched.png: individually removable component layers.
- assembly-fasteners-matched.png: collected fasteners.
- disassembly-side-panel.png: new generated removable cover, RGBA PNG.

Generated with the built-in image generation tool. Final prompt:
"Use case: scientific-educational. Create a single reusable game sprite for the removable side panel of a realistic black mid-tower desktop PC. Render only the detached opaque black steel rectangular side cover, directly straight on, front facing, vertical rectangle with width to height ratio 0.80, with subtle stamped rectangular inset, folded metal edges, two small captive thumbscrews along the left edge. No case, no components, no scene, no text, no labels. Center complete object with 5 percent padding. Transparent background with true alpha. Realistic studio lighting and charcoal brushed metal. This panel will overlay an open chassis and slide away during a disassembly teaching simulation. Portrait image."

The simulation renders component layers instead of baking installed parts into
one background. Safety and panel removal precede all internal work. Tool selection,
component selection, connector release, fasteners and latches gate lifting. The
cooler covers the CPU until removed. The board remains until its components are
removed. Scoring commits only after the removal animation; inventory is required
before completion. Reset reconstructs all local service state. Reduced-motion
preferences skip service and removal animations. The visual teaching sequence is
for this illustrated desktop; actual hardware service procedures vary.

Animations: side-cover slide, screw rotation, latch pivot, connector withdrawal,
and pointer-following component lift, animated return after a missed drop, and snap-in placement in the right-side ESD tray. Cable paths and mechanical close-up
cues are drawn in Flutter so they respond to the service state. Existing shared
assembly assets are retained rather than duplicating the same files.

The case view crops unused workbench scenery and uses the full available height.
Released parts require a mouse or touch drag into the side tray. A button cannot
complete a hardware removal. Tool, cable, fastener and latch checks remain required.
Canceled drops retain the service state and do not award progress. Scoring commits
only after the accepted drop animation. Drag geometry also follows the zoomed view.

Mechanical realism refinement:
- In-place mounting screws turn, rise and leave visible holes. Multi-screw groups
  release sequentially; cooler pairs follow a diagonal pattern.
- Connectors move continuously away from sockets. PSU leads remain disconnected
  in the case until the PSU is removed, rather than vanishing on button presses.
- DIMM clips, PCIe latch, CPU lever and retention plate preserve their open states.
- The cooler gently twists to break its thermal seal; removing it exposes used
  thermal compound. CPU extraction stays straight without a twist.
- Service hotspots are attached to the current connector, fastener or latch.
  The instruction-panel action remains available for the same operation.
- The panel first slides off its retaining tabs. Hardware drag feedback preserves
  aspect ratio and uses subtle depth with component-specific extraction direction.
- Tray settling uses a restrained ease-out rather than a springy bounce.
