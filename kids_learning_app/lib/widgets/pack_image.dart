import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../packs/pack_manager.dart';

/// Shows a picture from an installed pack.
/// A missing picture (for example Xylophone, not drawn yet) shows a
/// friendly placeholder instead of an error.
class PackImage extends StatelessWidget {
  const PackImage({
    super.key,
    required this.packId,
    required this.path,
    this.fit = BoxFit.contain,
  });

  final String packId;
  final String? path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final p = path;
    if (p == null) return const _Placeholder();
    return FutureBuilder<Uint8List?>(
      future: PackManager.instance.fileBytes(packId, p),
      builder: (context, snap) {
        final bytes = snap.data;
        if (bytes == null) {
          return snap.connectionState == ConnectionState.done
              ? const _Placeholder()
              : const SizedBox.shrink();
        }
        return Image.memory(bytes, fit: fit, gaplessPlayback: true);
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return const FittedBox(
      child: Icon(Icons.image_outlined, color: AppColors.line),
    );
  }
}
