// Package File Entry Model — VSP Mobile App
//
// A single file within a course package with its checksum.
// Mirrors PackageFileEntry from the backend (Story 4.1 PKG-CONTRACT-2).

import 'package:equatable/equatable.dart';

import 'package_content_type.dart';

/// A single file within a course package.
class PackageFileEntry extends Equatable {
  final String path;
  final String checksum;
  final int sizeBytes;
  final PackageContentType contentType;

  const PackageFileEntry({
    required this.path,
    required this.checksum,
    required this.sizeBytes,
    required this.contentType,
  });

  factory PackageFileEntry.fromJson(Map<String, dynamic> json) {
    return PackageFileEntry(
      path: json['path'] as String,
      checksum: json['checksum'] as String,
      sizeBytes: json['sizeBytes'] as int,
      contentType: PackageContentType.fromString(json['contentType'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'checksum': checksum,
    'sizeBytes': sizeBytes,
    'contentType': contentType.name,
  };

  @override
  List<Object?> get props => [path, checksum, sizeBytes, contentType];
}
