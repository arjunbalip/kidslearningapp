import 'package:flutter/material.dart';

import '../../features/common/coming_soon_screen.dart';

/// Shown if an activity is opened while its pack is not installed.
class MissingPackScreen extends StatelessWidget {
  const MissingPackScreen({super.key, required this.backTo});

  final String backTo;

  @override
  Widget build(BuildContext context) {
    return ComingSoonScreen(
      message: 'Ask a grown-up to download this!',
      backTo: backTo,
    );
  }
}
