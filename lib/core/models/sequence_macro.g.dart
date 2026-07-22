// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sequence_macro.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SequenceMacroAdapter extends TypeAdapter<SequenceMacro> {
  @override
  final int typeId = 1;

  @override
  SequenceMacro read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SequenceMacro(
      name: fields[0] as String,
      poses: (fields[1] as List).cast<ArmPose>(),
      stepDurationMs: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, SequenceMacro obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.poses)
      ..writeByte(2)
      ..write(obj.stepDurationMs);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SequenceMacroAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
