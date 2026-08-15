// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hive_game.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveGameAdapter extends TypeAdapter<HiveGame> {
  @override
  final typeId = 3;

  @override
  HiveGame read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveGame(
      created: fields[0] as DateTime?,
      updated: fields[1] as DateTime?,
      castles: (fields[2] as HiveList?)?.castHiveList(),
      title: fields[3] as String?,
      playerNames: (fields[4] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, HiveGame obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.created)
      ..writeByte(1)
      ..write(obj.updated)
      ..writeByte(2)
      ..write(obj.castles)
      ..writeByte(3)
      ..write(obj.title)
      ..writeByte(4)
      ..write(obj.playerNames);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveGameAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
