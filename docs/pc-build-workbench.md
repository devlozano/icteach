# Desktop build and wiring practicals

The assembly and cable-management catalog entries now render
`PcBuildWorkbench`, rather than the generic matching-slot board. The shared
chassis uses the same matched component PNGs as the disassembly practical.

Assembly has 52 operations across installation, internal wiring and commissioning.
The detailed wiring practical has 28 operations. Parts must be oriented and
dragged into place; tools, fasteners, socket retention and cable actions are
checked before the parent assessment receives a completed item. The parent
continues to own scoring, mistakes, time and progression.

The job sheet and operation log remain visible throughout the session. The
commissioning stage displays simulated POST observations and requires a written
service record, retained in that session's operation log. It is not a hardware
diagnostic tool or a certification assessment, and the log is not a saved report.

The illustrated kit uses DDR4, a 2.5-inch SATA SSD, an LGA-style retention plate,
four modeled motherboard fasteners and a documented example front-panel header.
Other hardware requires its manufacturer's procedure, mounting pattern and pinout.

Scope reference: [TESDA Computer Systems Servicing NC II Training Regulations](https://www.tesda.gov.ph/Downloadables/TRs/TR%20Computer%20Systems%20Servicing%20NC%20II%20.pdf),
Install and Configure Computer Systems: preparation, assembly, testing and
documentation. The training-kit operations are illustrative implementations,
not a claim that TESDA prescribes this chassis or exact sequence.

The other operation scenes retain their assessment flows and now show matched
switch, motherboard, maintenance and troubleshooting equipment instead of generic
equipment icons. RJ45 and disassembly retain their dedicated mechanics.

Validation: `flutter test test/pc_build_workbench_test.dart` exercises complete
build and wiring sessions at 640x320 and 1280x800, wrong tools, reversed parts,
and missing commissioning records. Optional `--dart-define=CAPTURE_BUILD=true`
produces local review PNGs on Windows using Arial from the system fonts folder.
