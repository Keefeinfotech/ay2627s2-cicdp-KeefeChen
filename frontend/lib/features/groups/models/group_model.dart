/// File Name: group_model.dart
/// Description: Data model for a group/workspace.
/// Author: Keefe Chen
library;

import 'package:json_annotation/json_annotation.dart';

@JsonSerializable()
class GroupModel {
  GroupModel({
    required this.id,
    required this.name,
    this.description,
    required this.memberCount,
    required this.createdAt,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) => _$GroupModelFromJson(json);

  Map<String, dynamic> toJson() => _$GroupModelToJson(this);

  final String id;
  final String name;
  final String? description;
  final int memberCount;
  final String createdAt;
}

GroupModel _$GroupModelFromJson(Map<String, dynamic> json) => GroupModel(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  memberCount: (json['memberCount'] as num).toInt(),
  createdAt: json['createdAt'] as String,
);

Map<String, dynamic> _$GroupModelToJson(GroupModel instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'memberCount': instance.memberCount,
  'createdAt': instance.createdAt,
};