import 'dart:io';

import 'package:btcc/src/state/data_store.dart';
import 'package:btcc/src/utils/debug_castle_assets.dart';
import 'package:btcc/src/utils/image_helper.dart';
import 'package:btcc/src/utils/navigation_helper.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:btcc/src/widgets/background_container.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Pick a repo fixture photo, then continue the normal Scan/Grid flow.
class DebugAssetPickerScreen extends StatefulWidget {
  final AddCastleToGameCallback addCastleCallback;
  final String gameTitle;
  final ValueChanged<String> onAssetChosen;

  const DebugAssetPickerScreen({
    super.key,
    required this.addCastleCallback,
    required this.gameTitle,
    required this.onAssetChosen,
  });

  @override
  State<DebugAssetPickerScreen> createState() => _DebugAssetPickerScreenState();
}

class _DebugAssetPickerScreenState extends State<DebugAssetPickerScreen> {
  List<String>? _files;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final files = await DebugCastleAssets.listImageFiles();
      if (!mounted) return;
      setState(() {
        _files = files;
        _error = files.isEmpty
            ? 'No photos in ${DebugCastleAssets.relativeDirectory}. '
                'On a phone the repo folder is not on the device — '
                'use Take or pick a photo, then export JSON + image.'
            : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _files = const [];
        _error = '$e';
      });
    }
  }

  Future<void> _onPick(String filePath) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      widget.onAssetChosen(DebugCastleAssets.basename(filePath));
      final store = Provider.of<DataStore>(context, listen: false);
      final destPath = await DebugCastleAssets.copyFileToDirectory(
        filePath,
        destDir: store.imagesTempPath,
      );
      final rotation = await ImageHelper.getImageRotation(destPath);
      if (!mounted) return;
      NavigationHelper.goToPhotoWorkflowScreen(
        context,
        destPath,
        rotation: rotation,
        replace: true,
        addCastleCallback: widget.addCastleCallback,
        gameTitle: widget.gameTitle,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = _files;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug photos'),
      ),
      body: BackgroundContainer(
        child: _busy
            ? const Center(child: CircularProgressIndicator())
            : files == null
                ? const Center(child: CircularProgressIndicator())
                : files.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error ?? 'No debug photos found',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: 0.85,
                        ),
                        itemCount: files.length,
                        itemBuilder: (context, index) {
                          final path = files[index];
                          return Material(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _onPick(path),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Image.file(
                                      File(path),
                                      fit: BoxFit.cover,
                                      cacheWidth: 400,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      DebugCastleAssets.basename(path),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
