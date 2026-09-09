import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../../models/module_model.dart';
import '../../services/cloudinary_service.dart';
import '../../services/module_service.dart';
import '../../services/notification_service.dart';

class CreateModulePage extends StatefulWidget {
  final String classId;
  final String className;
  final ModuleModel? moduleToEdit;

  const CreateModulePage({
    super.key,
    required this.classId,
    this.className = '',
    this.moduleToEdit,
  });

  @override
  State<CreateModulePage> createState() => _CreateModulePageState();
}

class _CreateModulePageState extends State<CreateModulePage> {
  final _formKey = GlobalKey<FormState>();
  final ModuleService _moduleService = ModuleService();
  final NotificationService _notificationService = NotificationService();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contentController = TextEditingController();
  final _youtubeLinkController = TextEditingController();
  final _fileLinkController = TextEditingController();

  bool _isLoading = false;
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  double _uploadProgress = 0;
  bool _isPublished = false;
  bool _isEditing = false;
  int _order = 0;
  String? _moduleId;
  final List<String> _competencies = [];
  bool _videoLinkValid = false;
  bool _fileLinkValid = false;

  final List<String> _competencyOptions = [
    'CSS-01: Install computer systems and networks',
    'CSS-02: Diagnose and troubleshoot computer systems',
    'CSS-03: Configure computer systems and networks',
    'CSS-04: Maintain computer systems and networks',
    'CSS-05: Setup computer networks',
    'CSS-06: Configure and maintain computer systems',
    'CSS-07: Identify computer parts and peripherals',
    'CSS-08: Assemble computer system units',
    'CSS-09: Troubleshoot computer hardware',
    'CSS-10: Use proper tools and equipment',
  ];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.moduleToEdit != null;

    if (_isEditing) {
      final module = widget.moduleToEdit!;
      _titleController.text = module.title;
      _descriptionController.text = module.description;
      _contentController.text = module.content;
      _youtubeLinkController.text = module.videoUrl ?? '';
      _fileLinkController.text = module.attachmentUrl ?? '';
      _competencies.addAll(module.competencies);
      _isPublished = module.isPublished;
      _order = module.order;
      _moduleId = module.id;

      if (_youtubeLinkController.text.isNotEmpty) {
        _validateYoutubeLink();
      }
      if (_fileLinkController.text.isNotEmpty) {
        _validateFileLink();
      }
    } else {
      _loadModuleCount();
    }

    _youtubeLinkController.addListener(_validateYoutubeLink);
    _fileLinkController.addListener(_validateFileLink);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    _youtubeLinkController.dispose();
    _fileLinkController.dispose();
    super.dispose();
  }

  void _validateYoutubeLink() {
    final url = _youtubeLinkController.text.trim();
    final isValid =
        url.isNotEmpty &&
        (url.contains('youtube.com/watch') ||
            url.contains('youtu.be/') ||
            url.contains('youtube.com/embed') ||
            url.contains('m.youtube.com'));
    setState(() {
      _videoLinkValid = isValid;
    });
  }

  void _validateFileLink() {
    final url = _fileLinkController.text.trim();
    final isValid =
        url.isNotEmpty &&
        (url.contains('drive.google.com') ||
            url.contains('docs.google.com') ||
            url.startsWith('https://'));
    setState(() {
      _fileLinkValid = isValid && _isValidUrl(url);
    });
  }

  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadModuleCount() async {
    try {
      final count = await _moduleService.getModuleCount(widget.classId);
      setState(() {
        _order = count;
      });
    } catch (e) {
      print('Error loading module count: $e');
    }
  }

  String extractYouTubeId(String url) {
    String videoId = '';
    if (url.contains('watch?v=')) {
      videoId = url.split('watch?v=').last.split('&').first;
    } else if (url.contains('youtu.be/')) {
      videoId = url.split('youtu.be/').last.split('?').first;
    } else if (url.contains('embed/')) {
      videoId = url.split('embed/').last.split('?').first;
    } else if (url.contains('m.youtube.com/watch')) {
      videoId = url.split('watch?v=').last.split('&').first;
    }
    return videoId;
  }

  Future<void> _openFileLink(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot open link'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot open link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Link copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _selectModuleFile() async {
    try {
      final file = await CloudinaryService.selectFile();

      if (file == null || !mounted) return;

      setState(() {
        _selectedFile = file;
        _uploadProgress = 0;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _saveModule() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You must be signed in.')));
      return;
    }

    final existingAttachment = widget.moduleToEdit?.attachmentUrl;
    final pastedAttachment = _fileLinkController.text.trim();
    if (!_isEditing && _selectedFile == null && pastedAttachment.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a module file.')));
      return;
    }

    setState(() {
      _isLoading = true;
      _isUploading = _selectedFile != null;
      _uploadProgress = _selectedFile == null ? 0 : 0.1;
    });

    try {
      final videoUrl = _youtubeLinkController.text.trim().isEmpty
          ? null
          : _youtubeLinkController.text.trim();

      if (videoUrl != null) {
        final videoId = extractYouTubeId(videoUrl);
        if (videoId.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Please enter a valid YouTube URL'),
              backgroundColor: Colors.orange,
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      CloudinaryUploadResult? uploadedFile;
      if (_selectedFile != null) {
        uploadedFile = await CloudinaryService.uploadFile(
          file: _selectedFile!,
          folder: CloudinaryService.modulesFolder,
        );
        if (!mounted) return;
        setState(() => _uploadProgress = 0.9);
      }

      final attachmentUrl =
          uploadedFile?.url ??
          (pastedAttachment.isNotEmpty ? pastedAttachment : existingAttachment);
      final existingModule = widget.moduleToEdit;

      final module = ModuleModel(
        id: _moduleId ?? '',
        classId: widget.classId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        content: _contentController.text.trim(),
        videoUrl: videoUrl,
        order: _order,
        competencies: _competencies,
        attachmentUrl: attachmentUrl,
        fileName: uploadedFile?.originalFilename ?? existingModule?.fileName,
        cloudinaryPublicId:
            uploadedFile?.publicId ?? existingModule?.cloudinaryPublicId,
        cloudinaryResourceType:
            uploadedFile?.resourceType ??
            existingModule?.cloudinaryResourceType,
        fileFormat: uploadedFile?.format ?? existingModule?.fileFormat,
        fileSize: uploadedFile?.bytes ?? existingModule?.fileSize,
        uploadedBy: uploadedFile != null
            ? currentUser.uid
            : existingModule?.uploadedBy,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isPublished: _isPublished,
      );

      if (_isEditing) {
        await _moduleService.updateModule(widget.classId, _moduleId!, module);

        if (_isPublished) {
          await _notificationService.notifyNewModule(
            widget.classId,
            _titleController.text.trim(),
          );
        }
      } else {
        await _moduleService.createModule(module);

        if (_isPublished) {
          await _notificationService.notifyNewModule(
            widget.classId,
            _titleController.text.trim(),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _uploadProgress = 1;
        _selectedFile = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isPublished
                ? '✅ Module ${_isEditing ? 'updated' : 'created'} and notifications sent!'
                : '✅ Module ${_isEditing ? 'updated' : 'saved'} as draft!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Error ${_isEditing ? 'updating' : 'creating'} module: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Module' : 'Create Module'),
        backgroundColor: const Color(0xFF0B2B4A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Switch(
            value: _isPublished,
            onChanged: (value) {
              setState(() => _isPublished = value);
            },
            activeThumbColor: Colors.green,
          ),
          const SizedBox(width: 8),
          const Text('Publish', style: TextStyle(color: Colors.white70)),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Class Name Display
              if (widget.className.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.class_, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Class: ${widget.className}',
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Module Title
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Module Title',
                  hintText: 'e.g., Introduction to Computer Systems',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Module title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Brief description of the module',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Video Section - YouTube
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.video_library, color: Colors.red),
                        const SizedBox(width: 8),
                        const Text(
                          'YouTube Video (Optional)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_videoLinkValid)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Valid Link',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.amber.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Paste any YouTube video link. The video will play inside the app!',
                              style: TextStyle(
                                color: Colors.amber.shade900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _youtubeLinkController,
                      decoration: InputDecoration(
                        labelText: 'YouTube Video URL',
                        hintText: 'https://www.youtube.com/watch?v=...',
                        prefixIcon: const Icon(Icons.link),
                        suffixIcon: _youtubeLinkController.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _youtubeLinkController.clear();
                                  setState(() {
                                    _videoLinkValid = false;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                              )
                            : null,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final videoId = extractYouTubeId(value);
                          if (videoId.isEmpty) {
                            return 'Please enter a valid YouTube URL';
                          }
                        }
                        return null;
                      },
                    ),
                    if (_youtubeLinkController.text.isNotEmpty &&
                        _videoLinkValid) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'YouTube video will play inside the app!',
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // File Attachment Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.attach_file, color: Color(0xFF0B2B4A)),
                        const SizedBox(width: 8),
                        const Text(
                          'Module File',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_fileLinkValid)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Valid Link',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isUploading ? null : _selectModuleFile,
                        icon: const Icon(Icons.attach_file),
                        label: Text(
                          _selectedFile == null
                              ? (widget.moduleToEdit?.fileName ??
                                    'Select module file')
                              : _selectedFile!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                          alignment: Alignment.centerLeft,
                        ),
                      ),
                    ),
                    if (_selectedFile != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_selectedFile!.name} • ${(_selectedFile!.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _isUploading
                                ? null
                                : () => setState(() => _selectedFile = null),
                            icon: const Icon(Icons.close, size: 19),
                            tooltip: 'Remove selected file',
                          ),
                        ],
                      ),
                    ],
                    if (_isUploading) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _uploadProgress),
                      const SizedBox(height: 5),
                      const Text(
                        'Uploading securely to Cloudinary...',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade700,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Paste a Google Drive, OneDrive, or any cloud storage shareable link.\n'
                              'Tip: Upload your file to Google Drive → Share → Copy link',
                              style: TextStyle(
                                color: Colors.blue.shade900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fileLinkController,
                      decoration: InputDecoration(
                        labelText: 'File Link (Google Drive, OneDrive, etc.)',
                        hintText: 'https://drive.google.com/file/d/...',
                        prefixIcon: const Icon(Icons.cloud),
                        suffixIcon: _fileLinkController.text.isNotEmpty
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      if (_fileLinkValid) {
                                        _openFileLink(_fileLinkController.text);
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.open_in_browser,
                                      size: 20,
                                      color: Colors.blue,
                                    ),
                                    tooltip: 'Test Link',
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      _copyLink(_fileLinkController.text);
                                    },
                                    icon: const Icon(
                                      Icons.copy,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                    tooltip: 'Copy Link',
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      _fileLinkController.clear();
                                      setState(() {
                                        _fileLinkValid = false;
                                      });
                                    },
                                    icon: const Icon(Icons.clear, size: 18),
                                  ),
                                ],
                              )
                            : null,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          if (!_isValidUrl(value)) {
                            return 'Please enter a valid URL';
                          }
                        }
                        return null;
                      },
                    ),
                    if (_fileLinkController.text.isNotEmpty &&
                        _fileLinkValid) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'File link is valid! Students can view/download from the link.',
                                style: TextStyle(
                                  color: Colors.green.shade800,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Competencies
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Competencies',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select relevant competencies for this module',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _competencyOptions.map((competency) {
                        final isSelected = _competencies.contains(competency);
                        return FilterChip(
                          label: Text(
                            competency,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _competencies.add(competency);
                              } else {
                                _competencies.remove(competency);
                              }
                            });
                          },
                          backgroundColor: Colors.grey.shade200,
                          selectedColor: const Color(0xFF0B2B4A),
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF0B2B4A)
                                  : Colors.grey.shade300,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    if (_competencies.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          '${_competencies.length} competency(s) selected',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Order and Status
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _order.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Module Order',
                        hintText: '0',
                        prefixIcon: Icon(Icons.numbers),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          _order = int.tryParse(value) ?? 0;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _isPublished
                            ? Colors.green.shade50
                            : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isPublished
                              ? Colors.green.shade200
                              : Colors.amber.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isPublished ? Icons.public : Icons.lock,
                            color: _isPublished ? Colors.green : Colors.amber,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isPublished ? 'Published' : 'Draft',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isPublished ? Colors.green : Colors.amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Notification Info (if published)
              if (_isPublished) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Students will be notified about this module when you save it.',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _isLoading || _isUploading ? null : _saveModule,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B2B4A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(
                    _isLoading
                        ? 'Uploading...'
                        : _isEditing
                        ? (_isPublished ? 'Update & Publish' : 'Update Draft')
                        : (_isPublished
                              ? 'Upload & Publish Module'
                              : 'Upload Module as Draft'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
