// Package License Model — VSP Mobile App
//
// License entry for a course package.
// Mirrors PackageLicense from the backend (Story 4.1 PKG-CONTRACT-2).

import 'package:equatable/equatable.dart';

/// A license governing package or content data.
class PackageLicense extends Equatable {
  final String name;
  final String? url;
  final String? spdxId;

  const PackageLicense({required this.name, this.url, this.spdxId});

  factory PackageLicense.fromJson(Map<String, dynamic> json) {
    return PackageLicense(
      name: json['name'] as String,
      url: json['url'] as String?,
      spdxId: json['spdxId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (url != null) 'url': url,
    if (spdxId != null) 'spdxId': spdxId,
  };

  @override
  List<Object?> get props => [name, url, spdxId];
}
