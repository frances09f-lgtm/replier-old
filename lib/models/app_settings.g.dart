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
      maxReplyDelaySeconds: fields[9] as int,
      preventDuplicateReplies: fields[4] as bool,
      ignoreGroupChats: fields[5] as bool,
      darkMode: fields[6] as bool,
      aiReplyEnabled: fields[10] as bool,
      groqApiKey: fields[11] as String,
      aiSystemPrompt: fields[12] as String,
      aiModelType: fields[13] != null ? fields[13] as String : 'groq',
      localModelPath: fields[14] != null ? fields[14] as String : '',
      localModelDownloaded: fields[15] != null ? fields[15] as bool : false,
      hfToken: fields[16] != null ? fields[16] as String : '',
      geminiApiKey: fields[17] != null ? fields[17] as String : '',
      geminiModel: fields[18] != null ? fields[18] as String : 'gemini-2.0-flash',
      lastUpdated: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.masterEnabled)
      ..writeByte(1)
      ..write(obj.whatsappEnabled)
      ..writeByte(2)
      ..write(obj.instagramEnabled)
      ..writeByte(3)
      ..write(obj.minReplyDelaySeconds)
      ..writeByte(9)
      ..write(obj.maxReplyDelaySeconds)
      ..writeByte(4)
      ..write(obj.preventDuplicateReplies)
      ..writeByte(5)
      ..write(obj.ignoreGroupChats)
      ..writeByte(6)
      ..write(obj.darkMode)
      ..writeByte(7)
      ..write(obj.lastUpdated)
      ..writeByte(10)
      ..write(obj.aiReplyEnabled)
      ..writeByte(11)
      ..write(obj.groqApiKey)
      ..writeByte(12)
      ..write(obj.aiSystemPrompt)
      ..writeByte(13)
      ..write(obj.aiModelType)
      ..writeByte(14)
      ..write(obj.localModelPath)
      ..writeByte(15)
      ..write(obj.localModelDownloaded)
      ..writeByte(16)
      ..write(obj.hfToken)
      ..writeByte(17)
      ..write(obj.geminiApiKey)
      ..writeByte(18)
      ..write(obj.geminiModel);
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
