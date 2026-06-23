import 'package:hive/hive.dart';

part 'reply_log.g.dart';

/// Model for reply logs
/// Stores history of all auto-replies sent
@HiveType(typeId: 2)
class ReplyLog extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String sender;

  @HiveField(2)
  String originalMessage;

  @HiveField(3)
  String autoReplySent;

  @HiveField(4)
  String appName;

  @HiveField(5)
  DateTime dateTime;

  @HiveField(6)
  String ruleId;

  ReplyLog({
    required this.id,
    required this.sender,
    required this.originalMessage,
    required this.autoReplySent,
    required this.appName,
    required this.dateTime,
    required this.ruleId,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'originalMessage': originalMessage,
      'autoReplySent': autoReplySent,
      'appName': appName,
      'dateTime': dateTime.toIso8601String(),
      'ruleId': ruleId,
    };
  }

  /// Create from JSON
  factory ReplyLog.fromJson(Map<String, dynamic> json) {
    return ReplyLog(
      id: json['id'],
      sender: json['sender'],
      originalMessage: json['originalMessage'],
      autoReplySent: json['autoReplySent'],
      appName: json['appName'],
      dateTime: DateTime.parse(json['dateTime']),
      ruleId: json['ruleId'],
    );
  }

  /// Create a copy with updated fields
  ReplyLog copyWith({
    String? id,
    String? sender,
    String? originalMessage,
    String? autoReplySent,
    String? appName,
    DateTime? dateTime,
    String? ruleId,
  }) {
    return ReplyLog(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      originalMessage: originalMessage ?? this.originalMessage,
      autoReplySent: autoReplySent ?? this.autoReplySent,
      appName: appName ?? this.appName,
      dateTime: dateTime ?? this.dateTime,
      ruleId: ruleId ?? this.ruleId,
    );
  }
}
