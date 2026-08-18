// Course Search Result DTO — VSP Mobile App
//
// Individual course search result with data freshness metadata.
// Mirrors CourseSearchResultDto from packages/contracts/schemas/course.yaml.

import 'package:equatable/equatable.dart';
import 'data_freshness.dart';
import 'package:vsp_mobile/features/measure/domain/measure_units.dart';
import 'package:vsp_mobile/features/profile/data/profile_dto.dart'
    show DistanceUnit;

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

  /// How many playable đường this club has. Tells the picker whether tapping
  /// goes straight into a round or has to ask which one.
  final int courseCount;

  /// True if an update is available compared to the mobile's downloaded version.
  ///
  /// Server-computed, and only meaningful on the single-course endpoint: a
  /// search returns a page and the server has one `downloadedVersion` to
  /// compare against all of it. The list decides for itself — see
  /// [latestPackageVersion].
  final bool updateAvailable;

  /// The version of the package the server would hand out for this course,
  /// or null where there is none to hand out.
  ///
  /// The half of the comparison the phone cannot know. The other half — which
  /// version this phone actually holds — is the half the server cannot know,
  /// and putting them together is what tells a golfer at nine in the evening
  /// whether tomorrow's course is really on their phone.
  final String? latestPackageVersion;
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
    this.courseCount = 1,
    required this.updateAvailable,
    this.latestPackageVersion,
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
      courseCount: (json['courseCount'] as num?)?.toInt() ?? 1,
      updateAvailable: json['updateAvailable'] as bool? ?? false,
      latestPackageVersion: json['latestPackageVersion'] as String?,
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
    'courseCount': courseCount,
    'updateAvailable': updateAvailable,
    'latestPackageVersion': latestPackageVersion,
    if (dataFreshness != null) 'dataFreshness': dataFreshness!.toJson(),
  };

  /// Display name — prefers courseName, falls back to facilityName.
  /// What this course is called — the đường, or the club where it has no name
  /// of its own.
  ///
  /// This is the course's own identity: the name a round is recorded against
  /// and the name the tee picker offers. It is deliberately not what the search
  /// card leads with; see [clubName].
  String get displayName => courseName ?? facilityName;

  /// The club, which is what a golfer typed into the search box.
  ///
  /// The card used to lead with [displayName], which was fine while every
  /// facility held one course called "<club> — Championship" and the club's
  /// name sat inside the course's. Loading the real đường broke it: searching
  /// "Long Biên" returned three cards reading "Đường A", "Đường B" and "Đường
  /// C", with the club's name nowhere on the screen — a search that worked and
  /// looked like it had failed.
  String get clubName => facilityName;

  /// Which đường, where the club has more than one and they are named.
  ///
  /// Null when the course is the club under another spelling — a facility with
  /// one course called "<club> — Championship" would otherwise print the club's
  /// name twice, once in each line.
  String? get unitName {
    final name = courseName;
    if (name == null || name.trim().isEmpty) {
      return null;
    }
    return name.contains('—') || name == facilityName ? null : name;
  }

  /// How far the golfer is from the course, in their own unit.
  ///
  /// Rolls over to kilometres — or miles, for a yards golfer — past the point
  /// where a number of metres stops being readable. [MeasureUnits] owns that
  /// threshold so the map and this list agree on where it sits.
  String formattedDistance(DistanceUnit unit) => distanceMeters == null
      ? ''
      : MeasureUnits.format(distanceMeters!, unit, rollOverAt: 1000);

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
    String? latestPackageVersion,
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
      latestPackageVersion: latestPackageVersion ?? this.latestPackageVersion,
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
    latestPackageVersion,
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
