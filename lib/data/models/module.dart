// Defines course modules and the study topics that belong to them.

import 'model_utils.dart';

final class Topic {
  Topic({
    required this.id,
    required this.moduleId,
    required this.name,
    required this.updatedAt,
    this.description,
    double mastery = 0,
    this.completedStudyMinutes = 0,
  }) : mastery = ModelUtils.clampUnit(mastery);

  final String id;
  final String moduleId;
  final String name;
  final String? description;
  final double mastery;
  final int completedStudyMinutes;
  final DateTime updatedAt;

  factory Topic.fromMap(Map<String, Object?> map, {String? id}) => Topic(
    id: id ?? ModelUtils.requiredString(map, 'id'),
    moduleId: ModelUtils.requiredString(map, 'moduleId'),
    name: ModelUtils.requiredString(map, 'name'),
    description: ModelUtils.optionalString(map, 'description'),
    mastery: ModelUtils.decimal(map, 'mastery', fallback: 0),
    completedStudyMinutes: ModelUtils.integer(
      map,
      'completedStudyMinutes',
      fallback: 0,
    ),
    updatedAt: ModelUtils.dateTime(
      map,
      'updatedAt',
      fallback: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    ),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'moduleId': moduleId,
    'name': name,
    'description': description,
    'mastery': mastery,
    'completedStudyMinutes': completedStudyMinutes,
    'updatedAt': updatedAt,
  };

  Topic copyWith({
    String? name,
    String? description,
    double? mastery,
    int? completedStudyMinutes,
    DateTime? updatedAt,
  }) => Topic(
    id: id,
    moduleId: moduleId,
    name: name ?? this.name,
    description: description ?? this.description,
    mastery: mastery ?? this.mastery,
    completedStudyMinutes: completedStudyMinutes ?? this.completedStudyMinutes,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

final class Module {
  Module({
    required this.id,
    required this.name,
    required this.code,
    required this.semester,
    required this.createdAt,
    required this.updatedAt,
    this.lecturer,
    this.colorHex = '#247CF8',
    this.iconName,
    this.notes,
    this.priorityWeight = 1,
    List<Topic> topics = const [],
  }) : topics = List.unmodifiable(topics);

  final String id;
  final String name;
  final String code;
  final String? lecturer;
  final String colorHex;
  final String? iconName;
  final String semester;
  final String? notes;
  final double priorityWeight;
  final List<Topic> topics;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Module.fromMap(Map<String, Object?> map, {String? id}) {
    final topics = ModelUtils.list(map, 'topics').map(
      (value) => Topic.fromMap(ModelUtils.objectMap(value, field: 'topics')),
    );
    return Module(
      id: id ?? ModelUtils.requiredString(map, 'id'),
      name: ModelUtils.requiredString(map, 'name'),
      code: ModelUtils.requiredString(map, 'code'),
      lecturer: ModelUtils.optionalString(map, 'lecturer'),
      colorHex: ModelUtils.optionalString(map, 'colorHex') ?? '#247CF8',
      iconName: ModelUtils.optionalString(map, 'iconName'),
      semester: ModelUtils.requiredString(map, 'semester'),
      notes: ModelUtils.optionalString(map, 'notes'),
      priorityWeight: ModelUtils.decimal(map, 'priorityWeight', fallback: 1),
      topics: topics.toList(),
      createdAt: ModelUtils.dateTime(
        map,
        'createdAt',
        fallback: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
      updatedAt: ModelUtils.dateTime(
        map,
        'updatedAt',
        fallback: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      ),
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'code': code,
    'lecturer': lecturer,
    'colorHex': colorHex,
    'iconName': iconName,
    'semester': semester,
    'notes': notes,
    'priorityWeight': priorityWeight,
    'topics': topics.map((topic) => topic.toMap()).toList(),
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  Module copyWith({
    String? name,
    String? code,
    String? lecturer,
    String? colorHex,
    String? iconName,
    String? semester,
    String? notes,
    double? priorityWeight,
    List<Topic>? topics,
    DateTime? updatedAt,
  }) => Module(
    id: id,
    name: name ?? this.name,
    code: code ?? this.code,
    lecturer: lecturer ?? this.lecturer,
    colorHex: colorHex ?? this.colorHex,
    iconName: iconName ?? this.iconName,
    semester: semester ?? this.semester,
    notes: notes ?? this.notes,
    priorityWeight: priorityWeight ?? this.priorityWeight,
    topics: topics ?? this.topics,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
