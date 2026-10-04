import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/config.dart';
import '../../app/responsive.dart';
import '../../app/theme.dart';
import '../../packs/pack_manager.dart';
import 'parent_access.dart';

/// Screen 8: the parent area's Packs page. Lists the packs on the server
/// and what is installed; download, update, cancel and remove.
class PacksScreen extends StatefulWidget {
  const PacksScreen({super.key});

  @override
  State<PacksScreen> createState() => _PacksScreenState();
}

class _PacksScreenState extends State<PacksScreen> {
  final PackManager _packs = PackManager.instance;

  @override
  void initState() {
    super.initState();
    // After the first frame, so listeners are not notified mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _packs.refreshManifest());
  }

  void _backToApp() {
    ParentAccess.close();
    context.go('/');
  }

  Future<void> _confirmRemove(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${_packs.titleFor(id)}?', style: baloo(22, weight: 700)),
        content: Text(
          'It can be downloaded again later. Stars are kept.',
          style: baloo(16, weight: 500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) await _packs.remove(id);
  }

  @override
  Widget build(BuildContext context) {
    final s = Screen.of(context);
    return Scaffold(
      backgroundColor: AppColors.surface100,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _packs,
          builder: (context, _) => Column(
            children: [
              _Header(onBack: _backToApp, onRefresh: _packs.refreshManifest),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: ListView(
                      padding: EdgeInsets.all(s.pad + 4),
                      children: [
                        Text('Content packs',
                            style: baloo(s.isTablet ? 32 : 26, weight: 700)),
                        Text(
                          'Download once, then play without internet.',
                          style: baloo(16, weight: 500, color: AppColors.inkMuted),
                        ),
                        const SizedBox(height: 16),
                        ..._statusBanners(),
                        for (final id in _packs.visiblePackIds) ...[
                          _PackRow(
                            id: id,
                            onDownload: () => _packs.download(id),
                            onCancel: () => _packs.cancelDownload(id),
                            onRemove: () => _confirmRemove(id),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_packs.manifestStatus == ManifestStatus.loaded &&
                            _packs.visiblePackIds.isEmpty)
                          _Banner(
                            icon: Icons.inbox_outlined,
                            text: 'The server has no packs yet.',
                          ),
                        const SizedBox(height: 16),
                        Text(
                          'Pack server: $packServerBase · App version $kAppVersion',
                          style: baloo(13, weight: 500, color: AppColors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _statusBanners() {
    final widgets = <Widget>[];
    if (_packs.manifestStatus == ManifestStatus.loading &&
        _packs.manifest.isEmpty) {
      widgets.add(const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ));
    }
    if (_packs.manifestStatus == ManifestStatus.offline) {
      widgets.add(_Banner(
        icon: Icons.wifi_off_rounded,
        text: 'Can\'t reach the pack server. Downloaded packs still work.',
      ));
    }
    final err = _packs.lastError;
    if (err != null) {
      widgets.add(_Banner(icon: Icons.error_outline_rounded, text: err));
    }
    if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 12));
    return widgets;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onRefresh});

  final VoidCallback onBack;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final s = Screen.of(context);
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: s.pad, vertical: 8),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: onBack,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandOrange,
              minimumSize: const Size(48, 48),
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(s.width < 420 ? 'Back' : 'Back to the app',
                style: baloo(16, weight: 700, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Grown-ups',
                overflow: TextOverflow.ellipsis, style: baloo(22, weight: 800)),
          ),
          IconButton(
            tooltip: 'Check for new packs',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface300,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.ink),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: baloo(15, weight: 600))),
        ],
      ),
    );
  }
}

class _PackRow extends StatelessWidget {
  const _PackRow({
    required this.id,
    required this.onDownload,
    required this.onCancel,
    required this.onRemove,
  });

  final String id;
  final VoidCallback onDownload;
  final VoidCallback onCancel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final packs = PackManager.instance;
    final state = packs.stateFor(id);
    final type = packs.typeFor(id);
    final entry = packs.entryFor(id);
    final task = packs.taskFor(id);

    final color = switch (type) {
      'letters' => AppColors.lettersBlue,
      'numbers' => AppColors.numbersGreen,
      _ => AppColors.playPink,
    };
    final badge = switch (type) {
      'letters' => 'Aa',
      'numbers' => '123',
      _ => '•',
    };

    final size = entry != null && entry.sizeBytes > 0
        ? ' · ${(entry.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '';
    final subtitle = switch (state) {
      PackState.available => 'Not downloaded$size',
      PackState.downloading =>
        'Downloading ${((task?.progress ?? 0) * 100).round()}%',
      PackState.installed => 'Downloaded · version ${packs.installedFor(id)?.version}',
      PackState.updateAvailable => 'Update available$size',
      PackState.needsAppUpdate => 'Needs a newer version of the app',
      PackState.missing => 'Files were cleared by the browser. Download again.',
    };

    final actions = <Widget>[
      if (state == PackState.available || state == PackState.missing)
        _action('Download', onDownload, filled: true),
      if (state == PackState.updateAvailable) _action('Update', onDownload, filled: true),
      if (state == PackState.downloading) _action('Cancel', onCancel),
      if (state == PackState.installed || state == PackState.updateAvailable)
        _action('Remove', onRemove),
    ];

    final info = Row(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(badge, style: baloo(26, weight: 800, color: Colors.white)),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(packs.titleFor(id), style: baloo(20, weight: 700)),
              Text(subtitle, style: baloo(15, weight: 600, color: AppColors.inkMuted)),
              if (state == PackState.downloading) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: (task?.progress ?? 0) > 0 ? task!.progress : null,
                    minHeight: 8,
                    color: AppColors.lettersBlue,
                    backgroundColor: AppColors.line,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (state == PackState.installed) ...[
          const SizedBox(width: 8),
          const Icon(Icons.check_circle_rounded, color: AppColors.numbersGreenText),
        ],
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: LayoutBuilder(builder: (context, c) {
        // Narrow phone: buttons go under the text.
        if (c.maxWidth < 460) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              info,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions,
                ),
              ],
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: info),
            const SizedBox(width: 12),
            ...[
              for (final a in actions) ...[a, const SizedBox(width: 8)],
            ],
          ],
        );
      }),
    );
  }

  Widget _action(String label, VoidCallback onTap, {bool filled = false}) {
    final style = baloo(16, weight: 700, color: filled ? Colors.white : AppColors.ink);
    return SizedBox(
      height: 48,
      child: filled
          ? FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.lettersBlue,
                shape: const StadiumBorder(),
              ),
              child: Text(label, style: style),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.inkMuted, width: 2),
                shape: const StadiumBorder(),
              ),
              child: Text(label, style: style),
            ),
    );
  }
}
