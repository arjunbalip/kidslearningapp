import 'package:flutter/material.dart';

import '../../features/common/coming_soon_screen.dart';

/// Shown if an activity is opened while its pack is not installed
/// (or is too old for the activity).
class MissingPackScreen extends StatelessWidget {
  const MissingPackScreen({
    super.key,
    required this.backTo,
    this.message = 'Ask a grown-up to download this!',
  });

  final String backTo;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ComingSoonScreen(
      message: message,
      backTo: backTo,
    );
  }
}
