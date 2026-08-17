import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:btcc/src/state/camera_store.dart';
import 'package:btcc/src/utils/log.dart';
import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/state/tf_store.dart';
import 'package:btcc/src/tflite/image_pipeline_mode.dart';
import 'package:btcc/src/tflite/tflite_model.dart';
import 'package:btcc/src/tflite/tflite_objects.dart';
import 'package:btcc/src/utils/asset_helper.dart';
import 'package:camera/camera.dart';
import 'package:exif/exif.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:btcc/src/widgets/guess_canvas.dart';


class DebugMLScreen extends StatefulWidget {

  final String? imagePath;

  DebugMLScreen(this.imagePath);

  @override
  State createState() => new DebugMLScreenState(this.imagePath);
}

class DebugMLScreenState extends State<DebugMLScreen> {

  List<TfliteProcessedGuess> guesses = [];
  List<TileLabels> filters = [];
  ui.Image? decodedImage;
  Map<String, IfdTag>? exifData;
  bool running = false;
  String status =
      'Tap Reset defaults, select an image, then Run model. Watch logcat for unravel: lines.';

  String? imagePath;

  DebugMLScreenState(this.imagePath);

  @override
  void initState() {
    super.initState();

    loadImageData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = Provider.of<TfStore>(context, listen: false);
      _resetDefaults(store);
    });
  }

  Future<void> _resetDefaults(TfStore store) async {
    store.scoreThreshold = 0.3;
    store.overlapThreshold = 0.45;
    store.mean = 0;
    store.std = 255;
    store.rotations = 3;
    store.useIdentifyModel = false;
    final ok = await store.init(TfliteModel.scoring, true);
    if (!mounted) return;
    setState(() {
      status = ok
          ? 'Defaults OK — ${store.pipelineMode.label}, size=${store.inputImageSize}, '
              'thr=${store.scoreThreshold}, mean=${store.mean}, std=${store.std}'
          : 'Failed to load scoring model';
    });
  }

  bool imageIsRotated() {
    if (exifData == null) {
      return false;
    }
    if(exifData!['Image Orientation'] == null){
      return true;
    }
    int rotation = exifData!['Image Orientation']!.values.firstAsInt();
    log('Rotation $rotation');
    if (rotation == 1 || rotation == 3 || rotation == 6 || rotation == 8) {
      return true;
    }

    return false;
  }

  loadImageData() async {
    if (this.imagePath == null) {
      log('image was null');
      return;
    }

    File image = new File(this.imagePath!);
    var bytes = await image.readAsBytes();
    var data = await readExifFromBytes(bytes);
    //print(data);
    log(data['Image Orientation']);
    var decoded = await decodeImageFromList(bytes);

    setState(() {
      decodedImage = decoded;
      exifData = data;
    });
  }

  Widget getGuessCard(TfliteProcessedGuess item) => Card(
    child: Text(item.toFormattedString()),
  );

  Widget getGuessesCanvas({required double height, required double width, 
    ui.Image? image}) {

    if (image == null) {
      return Container(
        width: width,
        height: height,
      );
    }

    bool rotated = imageIsRotated();
    int h = rotated ? image.height : image.width;
    int w = rotated ? image.width : image.height;

    return GuessCanvas(
      canvasSize: Size(width, height),
      guesses: _getFilteredGuesses(),
      imageHeight: h,
      imageWidth: w,
      colorMap: AssetHelper().labelToColorMap,
    );
  }

  Widget getColorKey() {
    if (guesses.length == 0) {
      return Container();
    }

    List<TileLabels> distinctLabels = guesses.map((e) => e.label as TileLabels).toSet().toList();
    return Container(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: distinctLabels.length,
        itemBuilder: (context, index) => InkWell(
          onTap: () {
            if (filters.contains(distinctLabels[index])) {
              List<TileLabels> copy = filters;
              copy.removeWhere((x) => x == distinctLabels[index]);
              setState(() {
                filters = copy;
              });
            }
            else {
              List<TileLabels> copy = filters;
              copy.add(distinctLabels[index]);
              setState(() {
                filters = copy;
              });
            }
          },
          child: Container(
            color: filters.contains(distinctLabels[index]) ? Colors.blueAccent : Colors.transparent,
            padding: EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              children: [
                Text(distinctLabels[index].toString()),
                Container(
                  height: 20,
                  width: 20,
                  color: AssetHelper().labelToColorMap[distinctLabels[index].toString()],
                )
              ],
            )
          )
        ),
      )
    );
  }

  Widget _getTextEditCard(String label, Function(String) callback) => Card(
    child: Row(
      children: [
        Text(label),
        Expanded(
          child: TextField(
            textAlign: TextAlign.center,
            showCursor: true,
            autofocus: false,
            onChanged: callback,
            keyboardType: TextInputType.number,
          )
        )
      ],
    ),
  );


  Widget _getTfParamsEditWidget() => Consumer<TfStore>(
    builder: (context, store, child) => Column(
      children: [
        SwitchListTile(
          value: store.useIdentifyModel,
          onChanged: (bool val) async {
            store.useIdentifyModel = val;
            final model = val ? TfliteModel.identify : TfliteModel.scoring;
            await store.init(model, true);
            setState(() {
              status =
                  'Loaded ${model.file.split('/').last} size=${store.inputImageSize}';
            });
          },
          title: Text('Use identify model'),
        ),
        SwitchListTile(
          title: Text('Legacy image pipeline'),
          subtitle: Text(
            store.pipelineMode == ImagePipelineMode.legacy
                ? 'ON: pre-August camera + detection (always-swap dims, strict edges, single EXIF rotation, original preview size)'
                : 'OFF (modern): odd-rotation swap, soft edges, multi-rotation search, orientation-aware preview',
          ),
          value: store.pipelineMode == ImagePipelineMode.legacy,
          onChanged: (legacy) {
            store.pipelineMode =
                legacy ? ImagePipelineMode.legacy : ImagePipelineMode.modern;
            setState(() {
              status = 'Pipeline → ${store.pipelineMode.label}';
            });
          },
        ),
        ElevatedButton(
          onPressed: () => _resetDefaults(store),
          child: const Text('Reset defaults (scoring / 1664 / thr 0.3)'),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: SelectableText(
            status,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
        Consumer<TfStore>(
          builder: (_, store, __) {
            final line = store.lastUnravelStatus;
            if (line.startsWith('unravel: (no run')) {
              return const SizedBox.shrink();
            }
            return Card(
              color: Colors.black87,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  line,
                  style: const TextStyle(
                    color: Colors.lightGreenAccent,
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            );
          },
        ),
        ElevatedButton(
          child: Text('${store.modelPath}'),
          onPressed: () async {
            var file = await FilePicker.platform.pickFiles();
            store.modelPath = file!.files.first.path!;
          },
        ),
        ElevatedButton(
          child: Text('${store.labelsPath}'),
          onPressed: () async {
            var file = await FilePicker.platform.pickFiles();
            store.labelsPath = file!.files.first.path!;
          },
        ),
        ElevatedButton(
          child: Text('${imagePath != null ? imagePath : 'Select an image'}'),
          onPressed: () async {
            var file = await FilePicker.platform.pickFiles();
            if (file == null) {
              log('no file selected');
              return;
            }

            setState(() {
              imagePath = file.files.first.path;
            });
            loadImageData();
          }
        ),
        Card(
          child: Row(
            children: [
              Text('Resolution:'),
              Expanded(child: Container()),
              Consumer<CameraStore>(
                builder: (_, cameraStore, __) => DropdownButton<ResolutionPreset>(
                  value: cameraStore.resolution,
                  onChanged: (ResolutionPreset? x) {
                    if (x != null) {
                      cameraStore.resolution = x;
                    }
                  },
                  items: ResolutionPreset.values.map((e) => DropdownMenuItem(
                    child: Text(e.toString()),
                    value: e,
                  )).toList()
                )
              ),
            ]
          ),
        ),
        Card(
          child: Row(
            children: [
              Text('CameraTech:'),
              Expanded(child: Container()),
              Consumer<CameraStore>(
                builder: (_, cameraStore, __) => DropdownButton<CameraTech>(
                  value: cameraStore.cameraTech,
                  onChanged: (CameraTech? x) {
                    if (x != null) {
                      cameraStore.cameraTech = x;
                    }
                  },
                  items: CameraTech.values.map((e) => DropdownMenuItem(
                    child: Text(e.toString()),
                    value: e,
                  )).toList()
                )
              ),
            ]
          ),
        ),
        Card(
          child: Row(
            children: [
              Text('Model:'),
              Expanded(child: Container()),
              Consumer<TfStore>(
                builder: (_, tfStore, __) => DropdownButton<String>(
                  value: tfStore.modelPath,
                  style: TextStyle(
                    fontSize: 10,
                  ),
                  onChanged: (String? x) async {
                    if (x == null) return;
                    var model = TfliteModel.modelFromPath(x);
                    await tfStore.init(model, true);
                  },
                  items: TfliteModel.allModels.map((e) => DropdownMenuItem(
                    child: Text(e.file),
                    value: e.file,
                  )).toList()
                )
              ),
            ]
          )
        ),
        _getTextEditCard('InputImageSize: ${store.inputImageSize}', (str) => setState((){ store.inputImageSize = int.parse(str);})),
        Row(
          children: [
            Expanded(child: _getTextEditCard('ScoreThreshold: ${store.scoreThreshold}', (str) => setState((){ store.scoreThreshold= double.parse(str);})),),
            Expanded(child: _getTextEditCard('Rotations: ${store.rotations}', (str) => setState((){ store.rotations = int.parse(str);})), )       
          ],
        ),
        Row(
          children: [
            Expanded(child: _getTextEditCard('mean: ${store.mean}', (str) => setState((){ store.mean = double.parse(str);})),),
            Expanded(child: _getTextEditCard('std: ${store.std}', (str) => setState((){ store.std = double.parse(str);})), )       
          ],
        ),
        Row(
          children: [
            Expanded(child: _getTextEditCard('OverlapThreshold: ${store.overlapThreshold}', (str) => setState((){ store.overlapThreshold = double.parse(str);})),),
            Expanded(child: Card(child: Text('Results: ${guesses.length}'))),
          ],
        ),
      ],
    ),
  );

  List<TfliteProcessedGuess> _getFilteredGuesses() {
    if (filters.length > 0) {
      return guesses.where((element) => filters.contains(element.label)).toList();
    }

    return guesses;
  }

  Widget _getImageAndBoxes(BuildContext context) {

    Widget child = getGuessesCanvas(
      width: min(
        TfliteModel.scoring.inputImageSize.toDouble(),
        MediaQuery.of(context).size.width
      ),
      height: min(
        TfliteModel.scoring.inputImageSize.toDouble(),
        MediaQuery.of(context).size.width
      ),
      image: decodedImage,
    );
    if (imagePath == null) {
      return Container(
        child: child
      );
    }

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: FileImage(File(imagePath!)),
          fit: BoxFit.contain,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('debug'),
    ),
    body: ListView(
      children: [
        _getTfParamsEditWidget(),
        Center( 
          child: _getImageAndBoxes(context)
        ),
        Consumer<TfStore>(builder: (ctx, store, child) => 
          store.running ? LinearProgressIndicator() : Container()),
        Consumer<TfStore>(builder: (ctx, store, child) => ElevatedButton(
          child: Text('Run model'),
          onPressed: (store.running || imagePath == null) ? null : () async {
            setState(() {
              status = 'Running…';
            });
            try {
              var res = await store.runOnImage(imagePath!);
              setState(() {
                guesses = res;
                status = res.isEmpty
                    ? '0 results.\n${store.lastUnravelStatus}'
                    : 'Results: ${res.length}\n${store.lastUnravelStatus}';
              });
            } catch (e, st) {
              setState(() {
                guesses = [];
                status = 'Error: $e\n$st';
              });
            }
          },
        )),
        Container(height: 10),
        getColorKey(),

      ]..addAll(_getFilteredGuesses().map((e) => getGuessCard(e)).toList())
    ),
  );
}
