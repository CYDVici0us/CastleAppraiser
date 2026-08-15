import 'package:btcc/src/models/exports.dart';
import 'package:btcc/src/utils/tile_helper.dart';
import 'package:btcc/src/utils/typedefs.dart';
import 'package:btcc/src/widgets/tile/tile_type_widget.dart';
import 'package:btcc/src/widgets/tile/tile_widget.dart';
import 'package:flutter/material.dart';

class ScoreCardWidget extends StatelessWidget {

  final Castle castle;
  ScoreCardWidget(this.castle);
  
  final double _scale = .36;
  double get _categoryScale  => _scale+.1;
  
  int _getTotal(Map<TileId, int> tiles) {
    int total = 0;
    tiles.values.forEach((element) => total+= element);
    return total;
  }

  List<Widget> _getTileMapAsRow(Map<TileId, int> tiles) => tiles.entries.map((entry) => 
    Column(
      children: [
        Text('${entry.value}'),
        TileWidget(TileHelper().getTileById(entry.key),
          scale: _scale,
        )
      ],
    )
  ).toList();


  Widget _getScoreCardRow(WidgetCallback builder, Map<TileId, int> tiles) => Row(
    children: [
      builder(),
    ]..addAll(_getTileMapAsRow(tiles))..addAll([
      Flexible(child: Container()),
      Text('${_getTotal(tiles)}'),
    ]),
  );

  Widget _getTileTypeScoreCardRow(TileType type, Map<TileId, int> tiles) => 
    _getScoreCardRow(() => TileTypeWidget(type, 
      scale: _categoryScale
    ), tiles);

  Widget _getSpecialTileScoreCardRow(TileId id, Map<TileId, int> tiles) => 
    _getScoreCardRow(() => TileWidget(TileHelper().getTileById(id),
      scale: _categoryScale,
    ), tiles);


  @override
  Widget build(BuildContext context) {
    castle.getScore();
    final scoreCard = castle.castleScoreCard!;
    return Column(
    children: [
      _getTileTypeScoreCardRow(TileType.Food, scoreCard.food),
      _getTileTypeScoreCardRow(TileType.Living, scoreCard.living),
      _getTileTypeScoreCardRow(TileType.Utility, scoreCard.utility),
      _getTileTypeScoreCardRow(TileType.Outdoor, scoreCard.outDoor),
      _getTileTypeScoreCardRow(TileType.Sleeping, scoreCard.sleeping),
      _getTileTypeScoreCardRow(TileType.Corridor, scoreCard.corridor),
      _getTileTypeScoreCardRow(TileType.Downstairs, scoreCard.downstairs),
      _getTileTypeScoreCardRow(TileType.Secret, scoreCard.secret),
      _getTileTypeScoreCardRow(TileType.Activity, scoreCard.activity),
      _getSpecialTileScoreCardRow(TileId.Tower, scoreCard.tower),
      _getSpecialTileScoreCardRow(TileId.Fountain, scoreCard.fountain),
      _getSpecialTileScoreCardRow(TileId.GrandFoyer, scoreCard.grandFoyer),
      _getSpecialTileScoreCardRow(TileId.BallRoomPerActivity, scoreCard.ballroom),
      _getSpecialTileScoreCardRow(TileId.BCPerRoomsAboveLevelThree, scoreCard.bonus),
      _getSpecialTileScoreCardRow(TileId.RoyalAttendantTaylor, scoreCard.royalAttendants),
      _getSpecialTileScoreCardRow(scoreCard.throneRoom.entries.first.key, scoreCard.throneRoom),
    ],
  );
  }
}