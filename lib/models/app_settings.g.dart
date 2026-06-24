// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 1;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      masterEnabled: fields[0] as bool,
      whatsappEnabled: fields[1] as bool,
      instagramEnabled: fields[2] as bool,
      minReplyDelaySeconds: fields[3] as int,
      preventDuplicateReplies: fields[4] as bool,
      ignoreGroupChats: fields[5] as bool,
      darkMode: fields[6] as bool,
      lastUpdated: fields[7] as DateTime,
      maxReplyDelaySeconds: fields[9] as int,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.masterEnabled)
      ..writeByte(1)
      ..write(obj.whatsappEnabled)
      ..writeByte(2)
      ..write(obj.instagramEnabled)
      ..writeByte(3)
      ..write(obj.minReplyDelaySeconds)
      ..writeByte(4)
      ..write(obj.preventDuplicateReplies)
      ..writeByte(5)
      ..write(obj.ignoreGroupChats)
      ..writeByte(6)
      ..write(obj.darkMode)
      ..writeByte(7)
      ..write(obj.lastUpdated)
      ..writeByte(9)
      ..write(obj.maxReplyDelaySeconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
