import 'package:equatable/equatable.dart';

/// The published versions of the mobile app for one platform
/// (`GET /app/version`, and the body of a 426 response).
class AppVersion extends Equatable {
  const AppVersion({this.latestBuild = 0, this.minimumBuild = 0, this.latestVersion, this.downloadUrl, this.notes});

  factory AppVersion.fromJson(Map<String, dynamic> json) => AppVersion(
    latestBuild: (json['latestBuild'] as num?)?.toInt() ?? 0,
    minimumBuild: (json['minimumBuild'] as num?)?.toInt() ?? 0,
    latestVersion: json['latestVersion'] as String?,
    downloadUrl: json['downloadUrl'] as String?,
    notes: json['notes'] as String?,
  );

  /// The newest build published, and its name ("1.0.0-rc.3").
  final int latestBuild;
  final String? latestVersion;

  /// Builds below this one can no longer be used: they must update.
  final int minimumBuild;

  /// Where to get the latest one; null when the backend has none set.
  final String? downloadUrl;
  final String? notes;

  /// What a build should do about this.
  AppUpdate updateFor(int build) => build < minimumBuild
      ? AppUpdate.required
      : build < latestBuild
      ? AppUpdate.available
      : AppUpdate.none;

  Map<String, dynamic> toJson() => {
    'latestBuild': latestBuild,
    'minimumBuild': minimumBuild,
    'latestVersion': latestVersion,
    'downloadUrl': downloadUrl,
    'notes': notes,
  };

  @override
  List<Object?> get props => [latestBuild, minimumBuild, latestVersion, downloadUrl, notes];
}

enum AppUpdate {
  /// Up to date.
  none,

  /// A newer one exists; this one still works.
  available,

  /// This build is refused: update to continue.
  required,
}
