import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/lrn_management_service.dart';

class LrnFolderBrowser extends StatefulWidget {
  final FirebaseFirestore? firestore;
  final bool enabled;
  final void Function(String id, String name) onFolderChanged;
  const LrnFolderBrowser({
    super.key,
    this.firestore,
    required this.enabled,
    required this.onFolderChanged,
  });
  @override
  State<LrnFolderBrowser> createState() => _LrnFolderBrowserState();
}

class _LrnFolderBrowserState extends State<LrnFolderBrowser> {
  String _selected = '';
  final _busy = <String>{};
  late final _db = widget.firestore ?? FirebaseFirestore.instance;
  late final _folders = _db
      .collection('lrn_folders')
      .orderBy('name')
      .snapshots();
  late final _records = _db.collection('lrn_master_list').snapshots();

  void _error() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to save. Check your connection and administrator permissions, then retry.',
          ),
        ),
      );
    }
  }

  Future<void> _createFolder() async {
    final draft = await showDialog<({String name, String kind})>(
      context: context,
      builder: (_) => const _FolderNameDialog(),
    );
    if (draft == null || !mounted) return;
    try {
      final id = await LrnManagementService(
        firestore: _db,
      ).createFolder(draft.name, kind: draft.kind);
      if (!mounted) return;
      setState(() => _selected = id);
      widget.onFolderChanged(id, draft.name);
    } catch (_) {
      _error();
    }
  }

  Future<void> _deleteFolder(String id, String name, int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $name folder?'),
        content: Text(
          count == 0
              ? 'This removes the empty folder.'
              : 'This removes $count LRN record${count == 1 ? '' : 's'} from the active list. Pending LRNs are deleted. Registered LRNs are archived so their student accounts and registration links remain protected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete folder and LRNs'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy.add(id));
    try {
      final removed = await LrnManagementService(
        firestore: _db,
      ).deleteFolder(id);
      if (!mounted) return;
      setState(() => _selected = '');
      widget.onFolderChanged('', 'Unfiled');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$name deleted. $removed LRN record${removed == 1 ? '' : 's'} processed.',
          ),
        ),
      );
    } catch (_) {
      _error();
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _delete(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final registered = doc.data()['isRegistered'] == true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete LRN ${doc.id}?'),
        content: Text(
          registered
              ? 'This removes the LRN from the active list. The student account and progress remain. Its registration link is retained to prevent this LRN being registered again.'
              : 'This removes the LRN from the master list. The student will no longer be able to register with it unless it is added again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy.add(doc.id));
    try {
      await LrnManagementService(firestore: _db).delete(doc.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('LRN ${doc.id} removed from the active list.'),
          ),
        );
      }
    } catch (_) {
      _error();
    } finally {
      if (mounted) setState(() => _busy.remove(doc.id));
    }
  }

  Future<void> _move(String lrn, String folder) async {
    setState(() => _busy.add(lrn));
    try {
      await LrnManagementService(firestore: _db).move(lrn, folder);
    } catch (_) {
      _error();
    } finally {
      if (mounted) setState(() => _busy.remove(lrn));
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _folders,
    builder: (context, foldersSnapshot) {
      if (foldersSnapshot.hasError) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Unable to load folders. Check your connection and administrator permissions.',
          ),
        );
      }
      if (!foldersSnapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final folders = {
        '': 'Unfiled',
        for (final doc in foldersSnapshot.data!.docs)
          doc.id: doc.data()['name'].toString(),
      };
      final folderKinds = {
        for (final doc in foldersSnapshot.data!.docs)
          doc.id: doc.data()['kind']?.toString() == 'batch' ? 'Batch' : 'Class',
      };
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _records,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Unable to load LRN records. Check your connection and permissions.',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final active = snapshot.data!.docs
              .where((doc) => doc.data()['archived'] != true)
              .toList();
          String folderOf(Map<String, dynamic> data) {
            final id = data['folderId']?.toString() ?? '';
            return folders.containsKey(id) ? id : '';
          }

          final records =
              active.where((doc) => folderOf(doc.data()) == _selected).toList()
                ..sort((a, b) => a.id.compareTo(b.id));
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final folder in folders.entries)
                      InputChip(
                        avatar: const Icon(Icons.folder_outlined, size: 18),
                        label: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 220),
                          child: Text(
                            '${folder.key.isEmpty ? '' : '${folderKinds[folder.key]}: '}${folder.value} (${active.where((d) => folderOf(d.data()) == folder.key).length})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        selected: _selected == folder.key,
                        deleteIcon: folder.key.isEmpty
                            ? null
                            : const Icon(Icons.delete_outline, size: 18),
                        deleteButtonTooltipMessage: folder.key.isEmpty
                            ? null
                            : 'Delete ${folder.value} folder and its LRNs',
                        onDeleted:
                            folder.key.isEmpty ||
                                !widget.enabled ||
                                _busy.contains(folder.key)
                            ? null
                            : () => _deleteFolder(
                                folder.key,
                                folder.value,
                                active
                                    .where(
                                      (d) => folderOf(d.data()) == folder.key,
                                    )
                                    .length,
                              ),
                        onPressed: !widget.enabled
                            ? null
                            : () {
                                setState(() => _selected = folder.key);
                                widget.onFolderChanged(
                                  folder.key,
                                  folder.value,
                                );
                              },
                      ),
                    OutlinedButton.icon(
                      onPressed: widget.enabled ? _createFolder : null,
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('New batch/class folder'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    runAlignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 10,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.badge_outlined),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                folders[_selected] ?? 'Folder',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '${records.length} LRN record${records.length == 1 ? '' : 's'}',
                              ),
                            ],
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          Chip(
                            avatar: const Icon(
                              Icons.verified_user_outlined,
                              size: 16,
                            ),
                            label: Text(
                              '${records.where((d) => d.data()['isRegistered'] == true).length} registered',
                            ),
                          ),
                          Chip(
                            avatar: const Icon(
                              Icons.schedule_outlined,
                              size: 16,
                            ),
                            label: Text(
                              '${records.where((d) => d.data()['isRegistered'] != true).length} pending',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (records.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Text(
                      'This folder is empty. Add an LRN, upload a CSV, or move records here.',
                    ),
                  )
                else
                  SizedBox(
                    height: 420,
                    child: ListView.builder(
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final doc = records[index], data = doc.data();
                        final registered = data['isRegistered'] == true;
                        final enabled =
                            widget.enabled && !_busy.contains(doc.id);
                        final officialName =
                            [
                                  data['firstName'],
                                  data['middleName'] ?? data['middleInitial'],
                                  data['lastName'],
                                  data['extension'] ?? data['suffix'],
                                ]
                                .map((value) => value?.toString().trim() ?? '')
                                .where((value) => value.isNotEmpty)
                                .join(' ');
                        return Card(
                          child: ListTile(
                            title: Text(
                              doc.id,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '$officialName\n${registered ? 'Registered' : 'Pending'}',
                            ),
                            isThreeLine: true,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PopupMenuButton<String>(
                                  tooltip: 'Move to folder',
                                  enabled: enabled,
                                  icon: const Icon(
                                    Icons.drive_file_move_outline,
                                  ),
                                  onSelected: (folder) => _move(doc.id, folder),
                                  itemBuilder: (_) => [
                                    for (final folder in folders.entries)
                                      PopupMenuItem(
                                        value: folder.key,
                                        enabled: folder.key != _selected,
                                        child: Text(folder.value),
                                      ),
                                  ],
                                ),
                                IconButton(
                                  tooltip: 'Delete LRN',
                                  onPressed: enabled
                                      ? () => _delete(doc)
                                      : null,
                                  icon: const Icon(Icons.delete_outline),
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog();
  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();
  String _kind = 'class';
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, (name: _name.text.trim(), kind: _kind));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('New batch or class folder'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _kind,
            decoration: const InputDecoration(
              labelText: 'Organize LRNs by',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'batch', child: Text('Batch')),
              DropdownMenuItem(value: 'class', child: Text('Class')),
            ],
            onChanged: (value) => setState(() => _kind = value ?? 'class'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            autofocus: true,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: _kind == 'batch' ? 'Batch name' : 'Class name',
              hintText: _kind == 'batch'
                  ? 'e.g. Batch 2026'
                  : 'e.g. Grade 12 - Section A',
              border: const OutlineInputBorder(),
            ),
            validator: (value) => (value?.trim().isEmpty ?? true)
                ? 'Enter a ${_kind == 'batch' ? 'batch' : 'class'} name.'
                : null,
            onFieldSubmitted: (_) => _submit(),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Create')),
    ],
  );
}
