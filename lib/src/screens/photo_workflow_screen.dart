import 'dart:io';



import 'package:btcc/src/models/enums/add_castle_mode.dart';

import 'package:btcc/src/models/exports.dart';

import 'package:btcc/src/utils/image_helper.dart';

import 'package:btcc/src/utils/navigation_helper.dart';

import 'package:btcc/src/utils/orientation_helper.dart';

import 'package:btcc/src/utils/typedefs.dart';

import 'package:btcc/src/widgets/background_container.dart';

import 'package:btcc/src/widgets/flow_breadcrumb.dart';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';



/// After gallery pick or camera capture: choose grid (manual) vs full scan.

class PhotoWorkflowScreen extends StatefulWidget {

  final String imagePath;

  final ImageRotation rotation;

  final AddCastleToGameCallback addCastleCallback;

  final int numPicturesTaken;

  final String? gameTitle;



  const PhotoWorkflowScreen({

    super.key,

    required this.imagePath,

    required this.addCastleCallback,

    this.rotation = ImageRotation.Normal,

    this.numPicturesTaken = 0,

    this.gameTitle,

  });



  @override

  State<PhotoWorkflowScreen> createState() => _PhotoWorkflowScreenState();

}



class _PhotoWorkflowScreenState extends State<PhotoWorkflowScreen> {

  final _expectedController = TextEditingController();

  String? _inputError;



  @override

  void dispose() {

    _expectedController.dispose();

    super.dispose();

  }



  int? _parseExpectedRoomCount() {

    final text = _expectedController.text.trim();

    if (text.isEmpty) return null;

    final n = int.tryParse(text);

    if (n == null || n < 1 || n > 60) {

      setState(() {

        _inputError = 'Enter a whole number from 1 to 60, or leave blank';

      });

      return null;

    }

    setState(() => _inputError = null);

    return n;

  }



  void _choose(BuildContext context, AddCastleMode mode) {

    final expected = _parseExpectedRoomCount();

    if (_inputError != null) return;



    switch (mode) {

      case AddCastleMode.tileSelection:

        NavigationHelper.goToTileSelectionFlowScreen(

          context,

          widget.imagePath,

          replace: true,

          addCastleCallback: widget.addCastleCallback,

          numPicturesTaken: widget.numPicturesTaken,

          gameTitle: widget.gameTitle,

          expectedRoomTileCount: expected,

        );

      case AddCastleMode.tileScan:

        NavigationHelper.goToCastleFrameScreen(

          context,

          widget.imagePath,

          rotation: widget.rotation,

          replace: true,

          addCastleCallback: widget.addCastleCallback,

          numPicturesTaken: widget.numPicturesTaken,

          gameTitle: widget.gameTitle,

          expectedRoomTileCount: expected,

        );

    }

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        title: FlowBreadcrumb(

          showHome: true,

          onHomeTap: () {

            OrientationHelper.lockPortrait();

            NavigationHelper.popToHome(context);

          },

          segments: [widget.gameTitle ?? 'Game', 'Add castle'],

          onSegmentTap: (index) {

            if (index == 0) Navigator.of(context).pop();

          },

        ),

      ),

      body: BackgroundContainer(

        child: SafeArea(

          child: Padding(

            padding: const EdgeInsets.symmetric(horizontal: 20),

            child: Column(

              children: [

                const SizedBox(height: 8),

                Text(

                  'How should we read this photo?',

                  style: Theme.of(context).textTheme.titleLarge,

                  textAlign: TextAlign.center,

                ),

                const SizedBox(height: 12),

                Expanded(

                  child: ClipRRect(

                    borderRadius: BorderRadius.circular(8),

                    child: Image.file(

                      File(widget.imagePath),

                      fit: BoxFit.contain,

                      width: double.infinity,

                    ),

                  ),

                ),

                const SizedBox(height: 16),

                TextField(

                  controller: _expectedController,

                  keyboardType: TextInputType.number,

                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],

                  decoration: InputDecoration(

                    labelText: 'Expected room tiles (optional)',

                    hintText: 'e.g. 22',

                    helperText:
                        'Room tiles only (not throne). Helps scan retry and '
                        'Grid progress. Tip: ~20–24 for a typical castle.',

                    errorText: _inputError,

                    border: const OutlineInputBorder(),

                    isDense: true,

                  ),

                  onChanged: (_) {

                    if (_inputError != null) {

                      setState(() => _inputError = null);

                    }

                  },

                ),

                const SizedBox(height: 16),

                _ModeCard(

                  icon: Icons.grid_on,

                  title: AddCastleMode.tileSelection.label,

                  description: AddCastleMode.tileSelection.description,

                  onTap: () => _choose(context, AddCastleMode.tileSelection),

                ),

                const SizedBox(height: 12),

                _ModeCard(

                  icon: Icons.document_scanner_outlined,

                  title: AddCastleMode.tileScan.label,

                  description: AddCastleMode.tileScan.description,

                  onTap: () => _choose(context, AddCastleMode.tileScan),

                ),

                const SizedBox(height: 16),

              ],

            ),

          ),

        ),

      ),

    );

  }

}



class _ModeCard extends StatelessWidget {

  final IconData icon;

  final String title;

  final String description;

  final VoidCallback onTap;



  const _ModeCard({

    required this.icon,

    required this.title,

    required this.description,

    required this.onTap,

  });



  @override

  Widget build(BuildContext context) {

    return Material(

      color: Theme.of(context).colorScheme.surfaceContainerHighest,

      borderRadius: BorderRadius.circular(12),

      child: InkWell(

        onTap: onTap,

        borderRadius: BorderRadius.circular(12),

        child: Padding(

          padding: const EdgeInsets.all(16),

          child: Row(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Icon(icon, size: 32),

              const SizedBox(width: 16),

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      title,

                      style: Theme.of(context).textTheme.titleMedium,

                    ),

                    const SizedBox(height: 4),

                    Text(

                      description,

                      style: Theme.of(context).textTheme.bodySmall,

                    ),

                  ],

                ),

              ),

              const Icon(Icons.chevron_right),

            ],

          ),

        ),

      ),

    );

  }

}


