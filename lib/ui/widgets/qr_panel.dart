import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/connection_info.dart';

/// Shows the join QR code plus the human readable code so members can join
/// either by scanning or by typing.
class QrPanel extends StatelessWidget {
  const QrPanel({super.key, required this.connection});

  final ConnectionInfo connection;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: QrImageView(
            data: connection.toPayload(),
            version: QrVersions.auto,
            size: 220,
            gapless: false,
          ),
        ),
        const SizedBox(height: 16),
        Text('Join code', style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        SelectableText(
          connection.code,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 6,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'On the same WiFi, open Songs → Join a session,\n'
          'then scan this code or type the join code.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
