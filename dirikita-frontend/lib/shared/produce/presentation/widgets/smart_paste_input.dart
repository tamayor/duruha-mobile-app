import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:duruha/core/widgets/duruha_snackbar.dart';

class SmartPasteInput extends StatefulWidget {
  final Function(List<String>) onValuesParsed;
  final List<String> fieldLabels;
  final String? promptToCopy;

  const SmartPasteInput({
    super.key,
    required this.onValuesParsed,
    this.fieldLabels = const [],
    this.promptToCopy,
  });

  @override
  State<SmartPasteInput> createState() => _SmartPasteInputState();
}

class _SmartPasteInputState extends State<SmartPasteInput> {
  final _smartPasteController = TextEditingController();
  List<String> _parsedPreview = [];

  @override
  void initState() {
    super.initState();
    _smartPasteController.addListener(_updatePreview);
  }

  @override
  void dispose() {
    _smartPasteController.removeListener(_updatePreview);
    _smartPasteController.dispose();
    super.dispose();
  }

  void _updatePreview() {
    final text = _smartPasteController.text;
    if (text.trim().isEmpty) {
      if (_parsedPreview.isNotEmpty) setState(() => _parsedPreview = []);
      return;
    }
    final values = _splitCsvValues(text);
    setState(() => _parsedPreview = values);
  }

  void _handleParse() {
    if (_smartPasteController.text.trim().isEmpty) return;

    final values = _splitCsvValues(_smartPasteController.text);
    widget.onValuesParsed(values);
  }

  List<String> _splitCsvValues(String content) {
    final values = <String>[];
    var current = StringBuffer();
    var inSingleQuote = false;
    var inDoubleQuote = false;
    // Basic CSV splitting respecting quotes and ARRAY brackets
    for (int i = 0; i < content.length; i++) {
      final char = content[i];

      if (char == "'" && !inDoubleQuote) {
        inSingleQuote = !inSingleQuote;
        current.write(char);
      } else if (char == '"' && !inSingleQuote) {
        inDoubleQuote = !inDoubleQuote;
        current.write(char);
      } else if (char == ',' && !inSingleQuote && !inDoubleQuote) {
        // Ignore comma inside ARRAY[...]
        if (current.toString().toUpperCase().contains('ARRAY[') &&
            !current.toString().contains(']')) {
          current.write(char);
        } else {
          values.add(current.toString().trim());
          current.clear();
        }
      } else {
        current.write(char);
      }
    }
    values.add(current.toString().trim());
    return values;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withAlpha(50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.tertiary.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.content_paste_go,
                size: 20,
                color: theme.colorScheme.onTertiary,
              ),
              const SizedBox(width: 8),
              Text(
                'Smart Paste',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onTertiary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.promptToCopy != null) ...[
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: widget.promptToCopy!),
                    );
                    DuruhaSnackBar.showSuccess(
                      context,
                      'Prompt copied to clipboard!',
                    );
                  },
                  icon: Icon(
                    Icons.copy_all,
                    size: 16,
                    color: theme.colorScheme.onTertiary,
                  ),
                  label: Text(
                    'Copy Prompt',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onTertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Paste comma-separated values to auto-fill (e.g., \'Name\', true, ...)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _smartPasteController,
                  style: theme.textTheme.bodySmall,
                  maxLines: 3,
                  minLines: 3,
                  decoration: InputDecoration(
                    hintText: "'Variety Name', true, 'Hybrid', ...",
                    isDense: true,
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.tertiary,
                  foregroundColor: theme.colorScheme.onTertiary,
                ),
                onPressed: () {
                  if (_smartPasteController.text.isNotEmpty) {
                    _handleParse();
                  } else {
                    Clipboard.getData(Clipboard.kTextPlain).then((data) {
                      if (data?.text != null) {
                        _smartPasteController.text = data!.text!;
                        // Listener will update preview
                        _handleParse();
                      }
                    });
                  }
                },
                icon: const Icon(Icons.download_rounded),
                tooltip: 'Parse & Fill',
              ),
            ],
          ),
          if (_parsedPreview.isNotEmpty && widget.fieldLabels.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              "PREVIEW:",
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.tertiary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_parsedPreview.length, (index) {
                final label = index < widget.fieldLabels.length
                    ? widget.fieldLabels[index]
                    : "Field ${index + 1}";
                final value = _parsedPreview[index];

                // Remove quotes for display if present
                final displayValue =
                    (value.startsWith("'") && value.endsWith("'")) ||
                        (value.startsWith('"') && value.endsWith('"'))
                    ? value.substring(1, value.length - 1)
                    : value;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodySmall,
                      children: [
                        TextSpan(
                          text: "$label: ",
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6), // Ghost key
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: displayValue,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}
