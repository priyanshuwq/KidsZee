// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arm_pose.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ArmPoseAdapter extends TypeAdapter<ArmPose> {
  @override
  final int typeId = 0;

  @override
  ArmPose read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ArmPose(
      base: fields[0] as double,
      shoulder: fields[1] as double,
      elbow: fields[2] as double,
      gripper: fields[3] as double,
      wristRoll: fields[5] as double,
      wristPitch: fields[6] as double,
      label: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ArmPose obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.base)
      ..writeByte(1)
      ..write(obj.shoulder)
      ..writeByte(2)
      ..write(obj.elbow)
      ..writeByte(3)
      ..write(obj.gripper)
      ..writeByte(4)
      ..write(obj.label)
      ..writeByte(5)
      ..write(obj.wristRoll)
      ..writeByte(6)
      ..write(obj.wristPitch);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArmPoseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
