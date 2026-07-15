import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/member_controller.dart';
import '../models/session_snapshot.dart';
import 'widgets/lyrics_view.dart';

/// What a member sees once they have joined — a live mirror of the leader.
class MemberView extends StatelessWidget {
  const MemberView({super.key});

  @override
  Widget build(BuildContext context) {
    final MemberController member = context.watch<MemberController>();
    final SessionSnapshot? snapshot = member.snapshot;
    final ThemeData theme = Theme.of(context);

    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          color: theme.colorScheme.primaryContainer,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(Icons.cast_connected,
                  size: 18, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  snapshot == null
                      ? 'Connected'
                      : '${snapshot.sessionTitle} • ${snapshot.leaderName}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              Icon(Icons.people_alt_outlined,
                  size: 16, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 4),
              Text('${snapshot?.memberCount ?? 1}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  )),
            ],
          ),
        ),
        Expanded(
          child: LyricsView(
            song: snapshot?.currentSong,
            sectionIndex: snapshot?.sectionIndex ?? 0,
            blanked: snapshot?.blanked ?? false,
          ),
        ),
      ],
    );
  }
}
