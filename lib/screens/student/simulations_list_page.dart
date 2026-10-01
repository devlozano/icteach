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
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFDCE7F3)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0B2B4A).withValues(alpha: .08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildSimulationArtwork(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      simulation.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      simulation.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, metadataConstraints) {
                        final outcomeWidth = (metadataConstraints.maxWidth - 62)
                            .clamp(120.0, 360.0);
                        return Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getCompetencyColor(
                                  simulation.competency,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                simulation.competency,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _getCompetencyColor(
                                    simulation.competency,
                                  ),
                                ),
                              ),
                            ),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: outcomeWidth,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  simulation.learningOutcome,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ),
                            FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(FirebaseAuth.instance.currentUser?.uid)
                                  .collection('simulation_progress')
                                  .doc('${classId}_${simulation.id}')
                                  .get(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData ||
                                    !snapshot.data!.exists) {
                                  return const SizedBox();
                                }
                                final data =
                                    snapshot.data!.data()
                                        as Map<String, dynamic>?;
                                if (data == null) return const SizedBox();
                                final passed = data['passed'] ?? false;
                                final percentage = data['percentage'] ?? 0;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: passed
                                        ? Colors.green.shade100
                                        : Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        passed
                                            ? Icons.check_circle
                                            : Icons.star,
                                        color: passed
                                            ? Colors.green
                                            : Colors.orange,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$percentage%',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: passed
                                              ? Colors.green.shade700
                                              : Colors.orange.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCompetencyColor(String competency) {
    switch (competency) {
      case 'COC1':
        return Colors.blue;
      case 'COC2':
        return Colors.green;
      default:
        return Colors.purple;
    }
  }

  IconData _getSimulationIcon(String type) {
    switch (type) {
      case 'assembly':
        return Icons.computer;
      case 'disassembly':
        return Icons.build_circle_outlined;
      case 'identification':
        return Icons.visibility;
      case 'networking':
        return Icons.wifi;
      case 'cabling':
        return Icons.linear_scale;
      default:
        return Icons.science;
    }
  }

  Widget _fallbackIcon() => Icon(
    _getSimulationIcon(simulation.type),
    size: 32,
    color: _getCompetencyColor(simulation.competency),
  );

  Widget _buildSimulationArtwork() {
    final asset = _getSimulationAsset(simulation.id);
    if (asset == null) return _fallbackIcon();
    return Image.asset(
      asset,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => _fallbackIcon(),
    );
  }

  String? _getSimulationAsset(String simulationId) {
    switch (simulationId) {
      case 'sim_coc1_assembly':
        return 'assets/simulations/icon-pc-assembly.png';
      case 'sim_coc1_disassembly':
        return 'assets/simulations/icon-pc-disassembly.png';
      case 'sim_coc1_cabling':
        return 'assets/simulations/icon-cable-management.png';
      case 'sim_coc1_identification':
        return 'assets/simulations/icon-hardware-identification.png';
      case 'sim_coc1_os_install':
        return 'assets/simulations/icon-os-installation.png';
      case 'sim_coc1_software_config':
        return 'assets/simulations/icon-software-configuration.png';
      case 'sim_coc1_maintenance':
        return 'assets/simulations/icon-preventive-maintenance.png';
      case 'sim_coc1_repair':
        return 'assets/simulations/icon-troubleshooting.png';
      case 'sim_coc2_topology':
        return 'assets/simulations/icon-network-topology.png';
      case 'sim_coc2_crimping':
        return 'assets/simulations/icon-rj45-crimping.png';
      case 'sim_coc2_ipconfig':
        return 'assets/simulations/icon-ip-configuration.png';
      case 'sim_coc2_diagnostics':
        return 'assets/simulations/icon-network-diagnostics.png';
      default:
        return null;
    }
  }
}
