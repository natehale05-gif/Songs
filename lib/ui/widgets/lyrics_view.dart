import 'package:flutter/material.dart';

import '../../models/song.dart';

/// Large, high contrast rendering of a single song section, used on both the
/// leader's preview and the members' screens.
class LyricsView extends StatelessWidget {
  const LyricsView({
    super.key,
    required this.song,
    required this.sectionIndex,
    this.blanked = false,
    this.showHeader = true,
  });

  final Song? song;
  final int sectionIndex;
  final bool blanked;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (blanked) {
      return Center(
        child: Icon(
          Icons.visibility_off_outlined,
          size: 48,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
        ),
      );
    }

    if (song == null || song!.sections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Waiting for the leader to choose a song...',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final int index = sectionIndex.clamp(0, song!.sections.length - 1);
    final section = song!.sections[index];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (showHeader) ...<Widget>[
            Text(
              song!.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              section.label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 24),
          ],
          for (final String line in section.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                line,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
