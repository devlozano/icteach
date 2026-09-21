import 'package:flutter/material.dart';

Future<void> showFullscreenImageGallery(
  BuildContext context,
  List<String> imageUrls, {
  int initialIndex = 0,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => _Gallery(imageUrls: imageUrls, initialIndex: initialIndex),
  ),
);

class _Gallery extends StatefulWidget {
  const _Gallery({required this.imageUrls, required this.initialIndex});
  final List<String> imageUrls;
  final int initialIndex;
  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  late final PageController controller;
  late int index;
  @override
  void initState() {
    super.initState();
    index = widget.initialIndex;
    controller = PageController(initialPage: index);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text(
        index.toString() + ' / ' + widget.imageUrls.length.toString(),
      ),
    ),
    body: PageView.builder(
      controller: controller,
      itemCount: widget.imageUrls.length,
      onPageChanged: (value) => setState(() => index = value),
      itemBuilder: (_, i) => Center(
        child: InteractiveViewer(
          minScale: .8,
          maxScale: 4,
          child: Image.network(
            widget.imageUrls[i],
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white,
              size: 64,
            ),
          ),
        ),
      ),
    ),
  );
}
