import 'dart:io';

import 'package:btcc/src/state/camera_store.dart';
import 'package:btcc/src/state/data_store.dart';
import 'package:btcc/src/state/tf_store.dart';
import 'package:btcc/src/utils/asset_helper.dart';
import 'package:btcc/src/utils/image_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'app_widget.dart';

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Future<String> getDir() async {
      if (kIsWeb || Platform.isWindows) {
        return '';
      }
      // Prefer app-specific external storage; fall back to documents if null
      // (scoped storage / some OEM builds).
      final dir = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      return ImageHelper.getFullImagePath(dir.path);
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CameraStore>(create: (_) => CameraStore()),
        ChangeNotifierProvider<TfStore>(create: (_) => TfStore()),
        ChangeNotifierProvider<DataStore>(create: (_) => DataStore(getDir)),
      ],
      child: _AssetBootstrap(child: AppWidget()),
    );
  }
}

/// Loads tile atlases after the first frame so the native splash can dismiss.
class _AssetBootstrap extends StatefulWidget {
  _AssetBootstrap({required this.child});

  final Widget child;

  @override
  State<_AssetBootstrap> createState() => _AssetBootstrapState();
}

class _AssetBootstrapState extends State<_AssetBootstrap> {
  late final Future<void> _assetsReady = AssetHelper().init();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _assetsReady,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            themeMode: ThemeMode.dark,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.black,
            ),
            home: Scaffold(
              backgroundColor: Colors.black,
              body: Builder(
                builder: (context) {
                  final logoSize =
                      (MediaQuery.sizeOf(context).shortestSide * 0.72)
                          .clamp(240.0, 420.0);
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          width: logoSize,
                          height: logoSize,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 32),
                        const CircularProgressIndicator(),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return MaterialApp(
            themeMode: ThemeMode.dark,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF121212),
            ),
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to load assets:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          );
        }

        return widget.child;
      },
    );
  }
}
