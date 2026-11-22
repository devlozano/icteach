class SimulationTutorial {
  const SimulationTutorial({required this.title, required this.url});

  final String title;
  final String url;
}

/// Curated external references for practice walkthroughs. These links are
/// deliberately kept out of graded workbenches.
class SimulationTutorials {
  static const Map<String, SimulationTutorial> bySimulationId = {
    'sim_coc1_assembly': SimulationTutorial(
      title: 'Slow, step-by-step PC build guide',
      url: 'https://www.youtube.com/watch?v=V38NoO2xiVw',
    ),
    'sim_coc1_disassembly': SimulationTutorial(
      title: 'Computer hardware disassembly guide',
      url: 'https://www.youtube.com/watch?v=Im4D5XZvV9g',
    ),
    'sim_coc1_cabling': SimulationTutorial(
      title: 'Detailed PC wiring guide',
      url: 'https://www.youtube.com/watch?v=BryNSA6ZAyU',
    ),
    'sim_coc2_network_setup': SimulationTutorial(
      title: 'LAN, router and DHCP configuration guide',
      url: 'https://www.youtube.com/watch?v=XAaguvvD-m8',
    ),
    'sim_coc2_topology': SimulationTutorial(
      title: 'Network topologies explained',
      url: 'https://www.youtube.com/watch?v=tBeNLrXAXRk',
    ),
    'sim_coc2_crimping': SimulationTutorial(
      title: 'RJ45 crimping and cable testing guide',
      url: 'https://www.youtube.com/watch?v=0HHpgvJllmo',
    ),
  };

  static SimulationTutorial? forId(String simulationId) =>
      bySimulationId[simulationId];
}
