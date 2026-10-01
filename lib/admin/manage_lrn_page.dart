import 'package:cloud_firestore/cloud_firestore.dart';
// lib/screens/admin/manage_lrn_page.dart
import '../widgets/lrn_folder_browser.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/lrn_csv_parser.dart';
import '../services/lrn_csv_import_service.dart';

class ManageLRNPage extends StatefulWidget {
  final bool useStandaloneScaffold;
  final FirebaseFirestore? firestore;

  const ManageLRNPage({
    super.key,
    this.useStandaloneScaffold = true,
    this.firestore,
  });

  @override
  State<ManageLRNPage> createState() => _ManageLRNPageState();
}

class _ManageLRNPageState extends State<ManageLRNPage> {
  bool _isUploading = false;
  String _folderId = '';
  String _folderName = 'Unfiled';
  final TextEditingController _lrnController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  final _middleInitialController = TextEditingController();
  final _suffixController = TextEditingController();

  int _processed = 0;
  int _total = 0;
  String? _importMessage;
  Future<void> _uploadCSV() async {
    if (_isUploading) return;
    setState(() {
      _isUploading = true;
      _processed = 0;
      _total = 0;
      _importMessage = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
        allowMultiple: false,
      );
      if (result == null || !mounted) return;
      final file = result.files.single;
      if (file.size > LrnCsvParser.maxBytes) {
        throw const FormatException('CSV files must be 5 MB or smaller.');
      }
      final bytes = file.bytes;
      if (bytes == null) {
        throw const FormatException(
          'Unable to read the selected file. Download it to your device and select it again.',
        );
      }
      final records = LrnCsvParser.parseBytes(bytes);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Import into $_folderName?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${records.length} valid records in ${file.name}.'),
                const SizedBox(height: 12),
                const Text(
                  'Existing LRNs will be skipped. Names and registration status already in the system will not be overwritten.',
                ),
                const SizedBox(height: 12),
                ...records
                    .take(5)
                    .map((r) => Text('${r.lrn} — ${r.displayName}')),
                if (records.length > 5) const Text('…and more records'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      setState(() => _total = records.length);
      final summary =
          await LrnCsvImportService(
            folderId: _folderId,
            firestore: widget.firestore,
          ).importRecords(
            records,
            onProgress: (processed, total) {
              if (mounted) setState(() => _processed = processed);
            },
          );
      if (!mounted) return;
      final message =
          'Import complete: ${summary.added} added, ${summary.skipped} existing records skipped.';
      setState(() => _importMessage = message);
      _showSnackBar(message, Colors.green);
    } on FormatException catch (e) {
      if (mounted) {
        setState(() => _importMessage = e.message);
        _showSnackBar(e.message, Colors.red);
      }
    } on LrnImportFailure catch (e) {
      if (mounted) {
        setState(() => _importMessage = e.toString());
        _showSnackBar(e.toString(), Colors.red);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _importMessage =
              'Unable to open or import the CSV. Please retry. $e',
        );
        _showSnackBar(_importMessage!, Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _lrnController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleInitialController.dispose();
    _suffixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listSection = LrnFolderBrowser(
      firestore: widget.firestore,
      enabled: !_isUploading,
      onFolderChanged: (id, name) => setState(() {
        _folderId = id;
        _folderName = name;
      }),
    );

    final pageContent = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Destination folder: $_folderName'),
              OutlinedButton.icon(
                onPressed: _isUploading ? null : _showAddLRNDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add LRN'),
              ),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    _isUploading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : ElevatedButton.icon(
                            onPressed: _uploadCSV,
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: const Text('Upload CSV'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0B2B4A),
                              foregroundColor: Colors.white,
                            ),
                          ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'CSV UTF-8, maximum 5 MB / 10,000 rows. Columns: LRN, First Name, Last Name; Middle Name or Middle Initial and Suffix are optional. Use headers when including a suffix. Set the LRN column format to General in Excel before saving. Verify that the CSV contains all 12 LRN digits, not scientific notation.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        listSection,
        if (_isUploading && _total > 0)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                LinearProgressIndicator(value: _processed / _total),
                Text('Imported $_processed of $_total records'),
              ],
            ),
          ),
        if (_importMessage != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(_importMessage!),
          ),
      ],
    );

    if (!widget.useStandaloneScaffold) {
      return SizedBox(width: double.infinity, child: pageContent);
    }

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: const Text('Manage LRN Master List'),
        backgroundColor: const Color(0xFF0B2B4A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddLRNDialog(),
            tooltip: 'Add LRN',
          ),
        ],
      ),
      body: SingleChildScrollView(child: pageContent),
    );
  }

  void _showAddLRNDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add LRN to $_folderName'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _lrnController,
                decoration: const InputDecoration(
                  labelText: 'LRN',
                  hintText: '12-digit LRN',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _middleInitialController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Middle Initial (Optional)',
                  hintText: 'A. or A. B.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _suffixController,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'Suffix (Optional)',
                  hintText: 'Jr., Sr., III',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final lrn = _lrnController.text.trim();
              final firstName = _firstNameController.text.trim();
              final lastName = _lastNameController.text.trim();

              if (!RegExp(r'^[0-9]{12}$').hasMatch(lrn) ||
                  firstName.isEmpty ||
                  firstName.length > 150 ||
                  lastName.isEmpty ||
                  lastName.length > 150) {
                _showSnackBar(
                  'Enter a 12-digit LRN and names of 1–150 characters.',
                  Colors.orange,
                );
                return;
              }

              try {
                final middleInitial = LrnCsvRecord.normalizeMiddleInitial(
                  _middleInitialController.text,
                );
                final suffix = _suffixController.text.trim();
                final result =
                    await LrnCsvImportService(
                      folderId: _folderId,
                      firestore: widget.firestore,
                    ).importRecords([
                      LrnCsvRecord(
                        lrn,
                        firstName,
                        lastName,
                        middleInitial,
                        extension: suffix,
                      ),
                    ]);
                if (!mounted || !context.mounted) return;
                if (result.skipped > 0) {
                  _showSnackBar(
                    'This LRN already exists. Its registration and code were preserved.',
                    Colors.orange,
                  );
                  return;
                }

                _showSnackBar('✅ LRN added successfully!', Colors.green);
                Navigator.pop(context);
                _lrnController.clear();
                _firstNameController.clear();
                _lastNameController.clear();
                _middleInitialController.clear();
                _suffixController.clear();
              } catch (e) {
                if (mounted) _showSnackBar('Error: $e', Colors.red);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0B2B4A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
