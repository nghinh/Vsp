// Course Search Result DTO — VSP Mobile App
//
// Individual course search result with data freshness metadata.
// Mirrors CourseSearchResultDto from packages/contracts/schemas/course.yaml.

import 'package:equatable/equatable.dart';
import 'data_freshness.dart';

/// Course search result — returned from /courses/search and /courses/nearby.
///
/// AC-1: text + geographic filters with paginated results.
/// AC-2: nearby search uses index-aware spatial filtering (server-side).
/// AC-3: includes verification, data freshness, download, and update state.
class CourseSearchResult extends Equatable {
  final int courseId;
  final int facilityId;
  final String facilityName;
  final String? courseName;
  final String? address;
  /// Where the facility is, or null when nobody has established that yet.
  ///
  /// Nullable on purpose. These used to default to 0.0 when the field was
  /// absent, which is not "unknown" — it is a point in the Gulf of Guinea,
  /// 10,000 km from Vietnam, and it is indistinguishable from a real answer.
  /// The database now holds courses whose location genuinely is not known, so
  /// the type has to be able to say so.
  final double? latitude;
  final double? longitude;
  final int holesCount;
  final int? parTotal;
  final double? rating;
  final int? slope;

  /// Distance in meters from the search point — only set for nearby searches.
  final double? distanceMeters;

  /// True if a published data package exists for this course.
  final bool hasPackage;

  /// True if an update is available compared to the mobile's downloaded version.
  final bool updateAvailable;
  final DataFreshness? dataFreshness;

  const CourseSearchResult({
    required this.courseId,
    required this.facilityId,
    required this.facilityName,
    this.courseName,
    this.address,
    this.latitude,
    this.longitude,
    required this.holesCount,
    this.parTotal,
    this.rating,
    this.slope,
    this.distanceMeters,
    required this.hasPackage,
    required this.updateAvailable,
    this.dataFreshness,
  });

  /// Parse from API response JSON (CourseSearchResultDto).
  factory CourseSearchResult.fromJson(Map<String, dynamic> json) {
    return CourseSearchResult(
      courseId: (json['courseId'] as num).toInt(),
      facilityId: (json['facilityId'] as num).toInt(),
      facilityName: json['facilityName'] as String,
      courseName: json['courseName'] as String?,
      address: json['address'] as String?,
      // Absent for a text-search hit, and for a facility nobody has located.
      // Carried through as null rather than coerced to a coordinate.
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      holesCount: (json['holesCount'] as num).toInt(),
      parTotal: (json['parTotal'] as num?)?.toInt(),
      rating: (json['rating'] as num?)?.toDouble(),
      slope: (json['slope'] as num?)?.toInt(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      hasPackage: json['hasPackage'] as bool? ?? false,
      updateAvailable: json['updateAvailable'] as bool? ?? false,
      dataFreshness: json['dataFreshness'] != null
          ? DataFreshness.fromJson(
              json['dataFreshness'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'courseId': courseId,
    'facilityId': facilityId,
    'facilityName': facilityName,
    if (courseName != null) 'courseName': courseName,
    if (address != null) 'address': address,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
    'holesCount': holesCount,
    if (parTotal != null) 'parTotal': parTotal,
    if (rating != null) 'rating': rating,
    if (slope != null) 'slope': slope,
    if (distanceMeters != null) 'distanceMeters': distanceMeters,
    'hasPackage': hasPackage,
    'updateAvailable': updateAvailable,
    if (dataFreshness != null) 'dataFreshness': dataFreshness!.toJson(),
  };

  /// Display name — prefers courseName, falls back to facilityName.
  String get displayName => courseName ?? facilityName;

  /// Formatted distance string (meters or km).
  String get formattedDistance {
    if (distanceMeters == null) return '';
    if (distanceMeters! >= 1000) {
      return '${(distanceMeters! / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters!.round()} m';
  }

  /// True if this course has official/verified data.
  bool get isVerified => dataFreshness?.isVerified ?? false;

  /// True if this course's data is considered stale.
  bool get isDataStale => dataFreshness?.isStale ?? false;

  CourseSearchResult copyWith({
    int? courseId,
    int? facilityId,
    String? facilityName,
    String? courseName,
    String? address,
    double? latitude,
    double? longitude,
    int? holesCount,
    int? parTotal,
    double? rating,
    int? slope,
    double? distanceMeters,
    bool? hasPackage,
    bool? updateAvailable,
    DataFreshness? dataFreshness,
  }) {
    return CourseSearchResult(
      courseId: courseId ?? this.courseId,
      facilityId: facilityId ?? this.facilityId,
      facilityName: facilityName ?? this.facilityName,
      courseName: courseName ?? this.courseName,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      holesCount: holesCount ?? this.holesCount,
      parTotal: parTotal ?? this.parTotal,
      rating: rating ?? this.rating,
      slope: slope ?? this.slope,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      hasPackage: hasPackage ?? this.hasPackage,
      updateAvailable: updateAvailable ?? this.updateAvailable,
      dataFreshness: dataFreshness ?? this.dataFreshness,
    );
  }

  @override
  List<Object?> get props => [
    courseId,
    facilityId,
    facilityName,
    courseName,
    address,
    latitude,
    longitude,
    holesCount,
    parTotal,
    rating,
    slope,
    distanceMeters,
    hasPackage,
    updateAvailable,
    dataFreshness,
  ];
}

/// Paginated search response wrapper.
///
/// Mirrors PageResponse<CourseSearchResultDto> from course.yaml.
class CourseSearchPage extends Equatable {
  final List<CourseSearchResult> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool first;
  final bool last;

  const CourseSearchPage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.first,
    required this.last,
  });

  factory CourseSearchPage.fromJson(Map<String, dynamic> json) {
    return CourseSearchPage(
      content: (json['content'] as List<dynamic>? ?? const [])
          .map((e) => CourseSearchResult.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 0,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      first: json['first'] as bool? ?? true,
      last: json['last'] as bool? ?? true,
    );
  }

  /// True if there is a next page.
  bool get hasNext => !last;

  /// True if there is a previous page.
  bool get hasPrevious => !first;

  @override
  List<Object?> get props => [
    content,
    page,
    size,
    totalElements,
    totalPages,
    first,
    last,
  ];
}
