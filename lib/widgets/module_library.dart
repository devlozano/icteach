import 'package:flutter/material.dart';
import '../models/module_model.dart';
import 'staff_collection_ui.dart';

class ModuleLibrary extends StatefulWidget {
  const ModuleLibrary({
    super.key,
    required this.modules,
    required this.itemBuilder,
    required this.onCreate,
  });
  final List<ModuleModel> modules;
  final Widget Function(ModuleModel module) itemBuilder;
  final VoidCallback onCreate;
  @override
  State<ModuleLibrary> createState() => _ModuleLibraryState();
}

class _ModuleLibraryState extends State<ModuleLibrary> {
  String _query = '';
  String _filter = 'All';
  @override
  Widget build(BuildContext context) {
    final published = widget.modules.where((m) => m.isPublished).length;
    final visible = widget.modules
        .where(
          (m) =>
              ('${m.title} ${m.description} ${m.competencies.join(' ')}')
                  .toLowerCase()
                  .contains(_query) &&
              (_filter == 'All' ||
                  (_filter == 'Published' ? m.isPublished : !m.isPublished)),
        )
        .toList();
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CollectionOverview(
                      title: 'Learning modules',
                      description:
                          'Organize lessons, publish learning materials, and follow student access.',
                      icon: Icons.auto_stories_outlined,
                      stats: [
                        ('Total', '${widget.modules.length}'),
                        ('Published', '$published'),
                        ('Drafts', '${widget.modules.length - published}'),
                      ],
                    ),
                    const SizedBox(height: 22),
                    CollectionSearch(
                      hint: 'Search modules or competencies',
                      onChanged: (v) =>
                          setState(() => _query = v.trim().toLowerCase()),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final filter in ['All', 'Published', 'Drafts'])
                          ChoiceChip(
                            label: Text(filter),
                            selected: _filter == filter,
                            selectedColor: const Color(0xFFDCEBFC),
                            onSelected: (_) => setState(() => _filter = filter),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '${visible.length} of ${widget.modules.length} modules',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (visible.isEmpty) ...[
                      CollectionEmpty(
                        title: widget.modules.isEmpty
                            ? 'Start your module library'
                            : 'No matching modules',
                        message: widget.modules.isEmpty
                            ? 'Create a lesson and publish it when it is ready for your students.'
                            : 'Try a different search or publishing filter.',
                        icon: Icons.auto_stories_outlined,
                      ),
                      if (widget.modules.isEmpty)
                        Center(
                          child: FilledButton.icon(
                            onPressed: widget.onCreate,
                            icon: const Icon(Icons.add),
                            label: const Text('Create module'),
                            style: FilledButton.styleFrom(
                              backgroundColor: staffNavy,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList.builder(
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final module = visible[index];
              return Center(
                key: ValueKey(module.id),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: widget.itemBuilder(module),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
