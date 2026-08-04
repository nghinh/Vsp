// Favorite Course DTO — VSP Mobile App
//
// Favorite course with course summary and favorited timestamp.
// Mirrors FavoriteCourseDto from packages/contracts/schemas/course.yaml.

import 'package:equatable/equatable.dart';

/// A favorited course — returned from GET /users/me/favorites.
class FavoriteCourse extends Equatable {
  final int courseId;
  final int facilityId;
  final String facilityName;
  final String? courseName;
  final String? address;
  final int holesCount;
  final DateTime favoritedAt;

  const FavoriteCourse({
    required this.courseId,
    required this.facilityId,
    required this.facilityName,
    this.courseName,
    this.address,
    required this.holesCount,
    required this.favoritedAt,
  });

  /// Parse from API response JSON (FavoriteCourseDto).
  factory FavoriteCourse.fromJson(Map<String, dynamic> json) {
    return FavoriteCourse(
      courseId: json['courseId'] as int,
      facilityId: json['facilityId'] as int,
      facilityName: json['facilityName'] as String,
      courseName: json['courseName'] as String?,
      address: json['address'] as String?,
      holesCount: json['holesCount'] as int,
      favoritedAt: DateTime.parse(json['favoritedAt'] as String),
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
    'favoritedAt': favoritedAt.toIso8601String(),
  };

  /// Display name — prefers courseName, falls back to facilityName.
  String get displayName => courseName ?? facilityName;

  /// Human-readable favorited time (relative).
  String get favoritedAtLabel {
    final diff = DateTime.now().difference(favoritedAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${favoritedAt.day}/${favoritedAt.month}/${favoritedAt.year}';
  }

  @override
  List<Object?> get props => [
    courseId,
    facilityId,
    facilityName,
    courseName,
    address,
    holesCount,
    favoritedAt,
  ];
}
