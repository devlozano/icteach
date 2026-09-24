import 'module_management_detail_page.dart';
import '../../widgets/module_list_card.dart';
import '../../widgets/module_library.dart';
import '../../widgets/summary_print_button.dart';
import '../../services/class_summary_service.dart';
import 'package:flutter/material.dart';
import '../../models/module_model.dart';
import '../../services/module_service.dart';
import 'content_lock_manager.dart';
import 'create_module_page.dart';
import 'learning_path_manager.dart';

class ManageModulesPage extends StatefulWidget {
  final String classId;
  final String className;

  const ManageModulesPage({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<ManageModulesPage> createState() => _ManageModulesPageState();
}

class _ManageModulesPageState extends State<ManageModulesPage> {
  final ModuleService _moduleService = ModuleService();
  late Stream<List<ModuleModel>> _modules;

  @override
  void initState() {
    super.initState();
    _modules = _moduleService.getModulesForClass(widget.classId);
  }

  @override
  void didUpdateWidget(covariant ManageModulesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId) {
      _modules = _moduleService.getModulesForClass(widget.classId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: const Text('Modules'),
        backgroundColor: const Color(0xFF0B2B4A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          SummaryPrintButton(
            title: 'Class summary - ${widget.className}',
            load: () => ClassSummaryService.load(widget.classId),
          ),
          IconButton(
            icon: const Icon(Icons.account_tree),
            tooltip: 'Lesson & assessment links',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LearningPathManager(classId: widget.classId),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ContentLockManager(classId: widget.classId),
                ),
              );
            },
            icon: const Icon(Icons.lock_clock),
            tooltip: 'Content Lock Settings',
          ),
        ],
      ),
      body: StreamBuilder<List<ModuleModel>>(
        stream: _modules,
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _modules = _moduleService.getModulesForClass(
                        widget.classId,
                      );
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final modules = snapshot.data ?? [];

          return ModuleLibrary(
            modules: modules,
            onCreate: _createModule,
            itemBuilder: (module) => ModuleListCard(
              module: module,
              onOpen: () => _openDetails(module),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createModule,
        backgroundColor: const Color(0xFF0B2B4A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create module'),
      ),
    );
  }

  // ✅ FIXED: Edit Module with full functionality
  Future<void> _createModule() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateModulePage(
          classId: widget.classId,
          className: widget.className,
        ),
      ),
    );
  }

  void _openDetails(ModuleModel module) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ModuleManagementDetailPage(
          classId: widget.classId,
          className: widget.className,
          module: module,
          modules: _modules,
        ),
      ),
    );
  }
}
