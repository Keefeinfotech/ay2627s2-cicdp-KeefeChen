/// File Name: reminder_model.dart
/// Description: Data model for a reminder.
/// Author: Keefe Chen
library;

import 'package:json_annotation/json_annotation.dart';

@JsonSerializable()
class ReminderModel {
  ReminderModel({
    required this.id,
    required this.message,
    required this.dueAt,
    required this.completed,
    required this.createdAt,
  });

  factory ReminderModel.fromJson(Map<String, dynamic> json) =>
      _$ReminderModelFromJson(json);

  Map<String, dynamic> toJson() => _$ReminderModelToJson(this);

  final String id;
  final String message;
  final DateTime dueAt;
  final bool completed;
  final DateTime createdAt;
}

ReminderModel _$ReminderModelFromJson(Map<String, dynamic> json) =>
    ReminderModel(
      id: json['id'] as String,
      message: json['message'] as String,
      dueAt: DateTime.parse(json['dueAt'] as String),
      completed: json['completed'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$ReminderModelToJson(ReminderModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'message': instance.message,
      'dueAt': instance.dueAt.toIso8601String(),
      'completed': instance.completed,
      'createdAt': instance.createdAt.toIso8601String(),
    };
