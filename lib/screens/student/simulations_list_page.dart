import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../data/simulation_data.dart';
import 'simulation_page.dart';

class SimulationsListPage extends StatefulWidget {
  final String classId;
  final String className;

  const SimulationsListPage({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<SimulationsListPage> createState() => _SimulationsListPageState();
}

class _SimulationsListPageState extends State<SimulationsListPage> {
  String _selectedCompetency = 'COC1';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        toolbarHeight: 44,
        leadingWidth: 46,
        titleSpacing: 2,
        automaticallyImplyLeading: false,
        elevation: 1,
        scrolledUnderElevation: 2,
        surfaceTintColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(7, 6, 3, 6),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => Navigator.maybePop(context),
              borderRadius: BorderRadius.circular(8),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF0B2B4A),
                size: 20,
              ),
            ),
          ),
        ),
        title: Tooltip(
          message: 'Simulations - ${widget.className}',
          child: const Text(
            'Simulations',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        backgroundColor: const Color(0xFF0B2B4A),
        foregroundColor: Colors.white,
        actions: [
          Container(
            height: 32,
            margin: const EdgeInsets.only(right: 7),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTabButton('COC1', 'COC1'),
                _buildTabButton('COC2', 'COC2'),
              ],
            ),
          ),
        ],
      ),
      body: _buildSimulationsList(),
    );
  }

  Widget _buildTabButton(String label, String value) {
    final isSelected = _selectedCompetency == value;
    return Material(
      color: isSelected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: () => setState(() => _selectedCompetency = value),
        borderRadius: BorderRadius.circular(7),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF0B2B4A) : Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimulationsList() {
    final simulations = SimulationData.getSimulationsByCompetency(
      _selectedCompetency,
    );

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: simulations.length,
      itemBuilder: (context, index) {
        final sim = simulations[index];
        return _SimulationCard(
          simulation: sim,
          classId: widget.classId,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SimulationPage(
                  classId: widget.classId,
                  className: widget.className,
                  simulationId: sim.id,
                  title: sim.title,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SimulationCard extends StatelessWidget {
  final dynamic simulation;
  final String classId;
  final VoidCallback onTap;

  const _SimulationCard({
    required this.simulation,
    required this.classId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      color: const Color(0xFF0B2B4A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 174,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(_backgroundAsset(simulation.id)),
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xF20A1D31),
                  Color(0xC70A1D31),
                  Color(0x550A1D31),
                ],
                stops: [0, .55, 1],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        simulation.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          height: 1.08,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 5),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  simulation.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
                const Spacer(),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _metadataChip(simulation.competency),
                    _metadataChip(simulation.learningOutcome, maxWidth: 250),
                    _progressBadge(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metadataChip(String label, {double maxWidth = 90}) => Container(
    constraints: BoxConstraints(maxWidth: maxWidth),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .16),
      border: Border.all(color: Colors.white24),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _progressBadge() => FutureBuilder<DocumentSnapshot>(
    future: FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .collection('simulation_progress')
        .doc('${classId}_${simulation.id}')
        .get(),
    builder: (context, snapshot) {
      if (!snapshot.hasData || !snapshot.data!.exists) {
        return const SizedBox.shrink();
      }
      final data = snapshot.data!.data() as Map<String, dynamic>?;
      if (data == null) return const SizedBox.shrink();
      final passed = data['passed'] ?? false;
      final percentage = data['percentage'] ?? 0;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: passed ? const Color(0xFF16A36A) : const Color(0xFFE58319),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              passed ? Icons.check_circle_rounded : Icons.star_rounded,
              color: Colors.white,
              size: 13,
            ),
            const SizedBox(width: 4),
            Text(
              '$percentage%',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    },
  );

  String _backgroundAsset(String simulationId) {
    return switch (simulationId) {
      'sim_coc2_network_setup' =>
        'assets/simulations/setup-network-workstation-v1.png',
      'sim_coc1_assembly' => 'assets/simulations/background-pc-assembly.png',
      'sim_coc1_disassembly' =>
        'assets/simulations/background-pc-disassembly.png',
      'sim_coc1_cabling' =>
        'assets/simulations/background-cable-management.png',
      'sim_coc1_identification' =>
        'assets/simulations/background-hardware-identification.png',
      'sim_coc1_os_install' => 'assets/simulations/setup-os-workstation-v1.png',
      'sim_coc1_software_config' =>
        'assets/simulations/setup-software-workstation-v1.png',
      'sim_coc1_maintenance' =>
        'assets/simulations/background-preventive-maintenance.png',
      'sim_coc1_repair' => 'assets/simulations/background-troubleshooting.png',
      'sim_coc2_topology' =>
        'assets/simulations/background-network-topology.png',
      'sim_coc2_crimping' => 'assets/simulations/background-rj45-crimping.png',
      'sim_coc2_ipconfig' =>
        'assets/simulations/background-ip-configuration.png',
      'sim_coc2_diagnostics' =>
        'assets/simulations/background-network-diagnostics.png',
      _ => 'assets/simulations/background-pc-assembly.png',
    };
  }
}
