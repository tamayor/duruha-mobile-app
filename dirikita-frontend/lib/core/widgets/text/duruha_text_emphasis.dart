import 'package:flutter/material.dart';

class DuruhaTextEmphasis extends StatelessWidget {
  final String text;
  final String breaker;
  final Color? mainColor;
  final Color? subColor;
  final double? mainSize;
  final double? subSize;
  final FontWeight? mainWeight;
  final FontWeight? subWeight;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign textAlign;

  const DuruhaTextEmphasis({
    super.key,
    required this.text,
    this.breaker = "()",
    this.mainColor,
    this.subColor,
    this.mainSize,
    this.subSize,
    this.mainWeight,
    this.subWeight,
    this.maxLines,
    this.overflow,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final defaultMainColor = mainColor ?? theme.colorScheme.onSurface;
    final defaultSubColor = subColor ?? theme.colorScheme.onSurfaceVariant;
    final defaultMainSize =
        mainSize ?? theme.textTheme.bodyMedium?.fontSize ?? 14.0;
    final defaultSubSize =
        subSize ?? theme.textTheme.bodySmall?.fontSize ?? 12.0;

    String startBreaker = breaker.isNotEmpty ? breaker[0] : '';
    // If the breaker is strictly one character, use it as both start and end,
    // otherwise if it's two characters like "()", use the second one as end.
    String endBreaker = breaker.length > 1 ? breaker[1] : startBreaker;

    if (startBreaker.isEmpty) {
      return Text(
        text,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
        style: TextStyle(
          color: defaultMainColor,
          fontSize: defaultMainSize,
          fontWeight: mainWeight,
        ),
      );
    }

    final List<TextSpan> spans = [];
    int currentIndex = 0;

    while (currentIndex < text.length) {
      int startIndex = text.indexOf(startBreaker, currentIndex);

      if (startIndex == -1) {
        // No more start breakers, add the rest of the text as main text
        spans.add(
          TextSpan(
            text: text.substring(currentIndex),
            style: TextStyle(
              color: defaultMainColor,
              fontSize: defaultMainSize,
              fontWeight: mainWeight,
            ),
          ),
        );
        break;
      }

      // Add text before the start breaker as main text
      if (startIndex > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, startIndex),
            style: TextStyle(
              color: defaultMainColor,
              fontSize: defaultMainSize,
              fontWeight: mainWeight,
            ),
          ),
        );
      }

      // Find the end breaker
      int endIndex = text.indexOf(endBreaker, startIndex + 1);

      if (endIndex == -1) {
        // Unmatched start breaker, just add from here to end as main text
        spans.add(
          TextSpan(
            text: text.substring(startIndex),
            style: TextStyle(
              color: defaultMainColor,
              fontSize: defaultMainSize,
              fontWeight: mainWeight,
            ),
          ),
        );
        break;
      }

      // Add the text inside the breakers as sub text (including the breakers themselves)
      spans.add(
        TextSpan(
          text: text.substring(startIndex, endIndex + 1),
          style: TextStyle(
            color: defaultSubColor,
            fontSize: defaultSubSize,
            fontWeight: subWeight,
          ),
        ),
      );

      currentIndex = endIndex + 1;
    }

    return RichText(
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      text: TextSpan(children: spans),
    );
  }
}
