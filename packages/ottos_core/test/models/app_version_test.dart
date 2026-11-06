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

  test('the body of a 426 has no notes, and reads as none', () {
    final refused = AppVersion.fromJson(const {
      'type': 'about:blank',
      'title': 'Upgrade Required',
      'status': 426,
      'code': 'APP_UPDATE_REQUIRED',
      'minimumBuild': 5,
      'latestBuild': 6,
      'latestVersion': '1.0.1',
      'downloadUrl': null,
    });
    expect(refused.notes, isNull);
    expect(refused.updateFor(4), AppUpdate.required);
  });
}
