import 'package:flutter/material.dart';

import '../../core/audio/audio_service.dart';
import '../../features/common/coming_soon_screen.dart';

/// Shown if an activity is opened while its pack is not installed,
/// or ([needsUpdate]) the installed pack is too old for the activity.
class MissingPackScreen extends StatelessWidget {
  const MissingPackScreen({
    super.key,
    required this.backTo,
    this.needsUpdate = false,
  });

  final String backTo;
  final bool needsUpdate;

  @override
  Widget build(BuildContext context) {
    return ComingSoonScreen(
      message: needsUpdate
          ? 'Ask a grown-up to update this!'
          : 'Ask a grown-up to download this!',
      prompt: needsUpdate ? Prompt.askUpdate : Prompt.askGrownUp,
      backTo: backTo,
    );
  }
}
