// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_castle.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveCastleAdapter extends TypeAdapter<HiveCastle> {
  @override
  final typeId = 1;

  @override
  HiveCastle read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveCastle(
      tiles: (fields[0] as List?)?.cast<TileId>(),
      tileWidth: (fields[1] as num?)?.toInt(),
      imagePath: fields[2] as String?,
      created: fields[3] as DateTime?,
      updated: fields[4] as DateTime?,
      title: fields[5] as String?,
      debugAssetName: fields[6] as String?,
      scanGuessJson: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, HiveCastle obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.tiles)
      ..writeByte(1)
      ..write(obj.tileWidth)
      ..writeByte(2)
      ..write(obj.imagePath)
      ..writeByte(3)
      ..write(obj.created)
      ..writeByte(4)
      ..write(obj.updated)
      ..writeByte(5)
      ..write(obj.title)
      ..writeByte(6)
      ..write(obj.debugAssetName)
      ..writeByte(7)
      ..write(obj.scanGuessJson);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveCastleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
