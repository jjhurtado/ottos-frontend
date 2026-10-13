import 'package:flutter_test/flutter_test.dart';
import 'package:ottos_core/ottos_core.dart';

void main() {
  const version = AppVersion(latestBuild: 15, minimumBuild: 14, latestVersion: '1.0.0-rc.3');

  test('below the minimum it must update; below the latest it may', () {
    expect(version.updateFor(13), AppUpdate.required);
    expect(version.updateFor(14), AppUpdate.available);
    expect(version.updateFor(15), AppUpdate.none);
    expect(version.updateFor(16), AppUpdate.none);
  });

  test('nothing published asks for nothing', () {
    final none = AppVersion.fromJson(const {
      'platform': 'ANDROID',
      'latestBuild': 0,
      'latestVersion': null,
      'minimumBuild': 0,
      'downloadUrl': null,
    });
    expect(none.updateFor(3), AppUpdate.none);
    expect(AppVersion.fromJson(none.toJson()), none);
  });
}
