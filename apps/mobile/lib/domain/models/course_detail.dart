// Course Detail DTO — VSP Mobile App
//
// Full course detail for AC-1: all fields visible on course detail screen.
// Mirrors CourseDetailDto from packages/contracts/schemas/course.yaml.

import 'package:equatable/equatable.dart';

import 'hole_summary.dart';
import 'tee_set_summary.dart';
import 'condition_entry.dart';
import 'data_freshness.dart';
import 'data_quality.dart';

/// Full course detail — AC-1 aggregate.
class CourseDetail extends Equatable {
  final int courseId;
  final int facilityId;
  final String facilityName;
  final String? phone;
  final String? website;
  final String? address;
  final double latitude;
  final double longitude;
  final int holesCount;
  final int? parTotal;
  final double? rating;
  final int? slope;
  final List<String> imageUrls;
  final List<String> facilities;
  final List<String> localRules;
  final List<HoleSummary> holes;
  final List<TeeSetSummary> teeSets;
  final List<ConditionEntry> conditions;
  final DataFreshness? dataFreshness;
  final AccuracyClass? accuracyClass;

  const CourseDetail({
    required this.courseId,
    required this.facilityId,
    required this.facilityName,
    this.phone,
    this.website,
    this.address,
    required this.latitude,
    required this.longitude,
    required this.holesCount,
    this.parTotal,
    this.rating,
    this.slope,
    required this.imageUrls,
    required this.facilities,
    required this.localRules,
    required this.holes,
    required this.teeSets,
    required this.conditions,
    this.dataFreshness,
    this.accuracyClass,
  });

  /// Parse from API response JSON.
  factory CourseDetail.fromJson(Map<String, dynamic> json) {
    return CourseDetail(
      courseId: (json['courseId'] as num).toInt(),
      facilityId: (json['facilityId'] as num).toInt(),
      facilityName: json['facilityName'] as String,
      phone: json['phone'] as String?,
      website: json['website'] as String?,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      holesCount: (json['holesCount'] as num?)?.toInt() ?? 0,
      parTotal: (json['parTotal'] as num?)?.toInt(),
      rating: (json['rating'] as num?)?.toDouble(),
      slope: (json['slope'] as num?)?.toInt(),
      imageUrls:
          (json['imageUrls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      facilities:
          (json['facilities'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      localRules:
          (json['localRules'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      holes:
          (json['holes'] as List<dynamic>?)
              ?.map((e) => HoleSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      teeSets:
          (json['teeSets'] as List<dynamic>?)
              ?.map((e) => TeeSetSummary.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      conditions:
          (json['conditions'] as List<dynamic>?)
              ?.map((e) => ConditionEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      dataFreshness: json['dataFreshness'] != null
          ? DataFreshness.fromJson(
              json['dataFreshness'] as Map<String, dynamic>,
            )
          : null,
      // The class travels inside dataFreshness; the top-level field is
      // accepted too so an older payload still parses. Neither present means
      // the app knows nothing, which is not the same as class D data — see
      // dataQuality below.
      accuracyClass: _readAccuracyClass(json),
    );
  }

  static AccuracyClass? _readAccuracyClass(Map<String, dynamic> json) {
    final top = json['accuracyClass'] as String?;
    if (top != null) return AccuracyClass.fromString(top);
    final freshness = json['dataFreshness'] as Map<String, dynamic>?;
    final nested = freshness?['accuracyClass'] as String?;
    return nested != null ? AccuracyClass.fromString(nested) : null;
  }

  Map<String, dynamic> toJson() => {
    'courseId': courseId,
    'facilityId': facilityId,
    'facilityName': facilityName,
    if (phone != null) 'phone': phone,
    if (website != null) 'website': website,
    if (address != null) 'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'holesCount': holesCount,
    if (parTotal != null) 'parTotal': parTotal,
    if (rating != null) 'rating': rating,
    if (slope != null) 'slope': slope,
    'imageUrls': imageUrls,
    'facilities': facilities,
    'localRules': localRules,
    'holes': holes.map((h) => h.toJson()).toList(),
    'teeSets': teeSets.map((t) => t.toJson()).toList(),
    'conditions': conditions.map((c) => c.toJson()).toList(),
    if (dataFreshness != null) 'dataFreshness': dataFreshness!.toJson(),
    if (accuracyClass != null) 'accuracyClass': accuracyClass!.value,
  };

  /// Resolved DataQuality — combines dataFreshness + accuracyClass.
  DataQuality? get dataQuality {
    if (dataFreshness == null) return null;
    return DataQuality.fromDataFreshness(
      dataFreshness!,
      accuracyClass ?? AccuracyClass.classD,
    );
  }

  /// Formatted coordinates string.
  String get formattedCoordinates =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  /// True if contact info is available.
  bool get hasContact => phone != null || website != null || address != null;

  /// True if images are available.
  bool get hasImages => imageUrls.isNotEmpty;

  /// True if facilities are available.
  bool get hasFacilities => facilities.isNotEmpty;

  /// True if local rules are available.
  bool get hasLocalRules => localRules.isNotEmpty;

  /// True if conditions are available.
  bool get hasConditions => conditions.isNotEmpty;

  /// True if ratings are available.
  bool get hasRatings => rating != null || slope != null;

  @override
  List<Object?> get props => [
    courseId,
    facilityId,
    facilityName,
    phone,
    website,
    address,
    latitude,
    longitude,
    holesCount,
    parTotal,
    rating,
    slope,
    imageUrls,
    facilities,
    localRules,
    holes,
    teeSets,
    conditions,
    dataFreshness,
    accuracyClass,
  ];
}
