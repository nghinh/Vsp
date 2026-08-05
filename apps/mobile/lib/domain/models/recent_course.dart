// Recent Course DTO — VSP Mobile App
//
// Recently viewed course with course summary and viewed timestamp.
// Mirrors RecentCourseDto from packages/contracts/schemas/course.yaml.

import 'package:equatable/equatable.dart';

/// A recently viewed course — returned from GET /users/me/recent.
class RecentCourse extends Equatable {
  final int courseId;
  final int facilityId;
  final String facilityName;
  final String? courseName;
  final String? address;
  final int holesCount;
  final DateTime viewedAt;

  const RecentCourse({
    required this.courseId,
    required this.facilityId,
    required this.facilityName,
    this.courseName,
    this.address,
    required this.holesCount,
    required this.viewedAt,
  });

  /// Parse from API response JSON (RecentCourseDto).
  factory RecentCourse.fromJson(Map<String, dynamic> json) {
    return RecentCourse(
      courseId: (json['courseId'] as num).toInt(),
      facilityId: (json['facilityId'] as num).toInt(),
      facilityName: json['facilityName'] as String,
      courseName: json['courseName'] as String?,
      address: json['address'] as String?,
      holesCount: (json['holesCount'] as num).toInt(),
      viewedAt: DateTime.parse(json['viewedAt'] as String),
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'courseId': courseId,
    'facilityId': facilityId,
    'facilityName': facilityName,
    if (courseName != null) 'courseName': courseName,
    if (address != null) 'address': address,
    'holesCount': holesCount,
    'viewedAt': viewedAt.toIso8601String(),
  };

  /// Display name — prefers courseName, falls back to facilityName.
  String get displayName => courseName ?? facilityName;

  /// Human-readable viewed time (relative).
  String get viewedAtLabel {
    final diff = DateTime.now().difference(viewedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${viewedAt.day}/${viewedAt.month}/${viewedAt.year}';
  }

  @override
  List<Object?> get props => [
    courseId,
    facilityId,
    facilityName,
    courseName,
    address,
    holesCount,
    viewedAt,
  ];
}
