import 'package:flutter/material.dart';
import '../services/summary_pdf_service.dart';
export '../services/summary_pdf_service.dart' show SummarySection;

class SummaryPrintButton extends StatefulWidget {
  final String title;
  final Future<List<SummarySection>> Function() load;
  const SummaryPrintButton({
    super.key,
    required this.title,
    required this.load,
  });
  @override
  State<SummaryPrintButton> createState() => _SummaryPrintButtonState();
}

class _SummaryPrintButtonState extends State<SummaryPrintButton> {
  bool busy = false;
  Future<void> _print() async {
    setState(() => busy = true);
    try {
      await SummaryPdfService.printSummary(widget.title, await widget.load());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Unable to print: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 700) {
      return IconButton(
        onPressed: busy ? null : _print,
        tooltip: busy ? 'Preparing summary' : 'Print summary',
        icon: const Icon(Icons.print_outlined),
      );
    }
    return TextButton.icon(
      onPressed: busy ? null : _print,
      style: TextButton.styleFrom(foregroundColor: IconTheme.of(context).color),
      icon: const Icon(Icons.print_outlined),
      label: Text(busy ? 'Preparing…' : 'Print summary'),
    );
  }
}
