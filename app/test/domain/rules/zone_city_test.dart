import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/rules/zone_city.dart';

void main() {
  test('the last segment, with spaces for underscores', () {
    expect(zoneCity('America/New_York'), 'New York');
    expect(zoneCity('Asia/Kolkata'), 'Kolkata');
    expect(zoneCity('Europe/London'), 'London');
    expect(zoneCity('Europe/Isle_of_Man'), 'Isle of Man');
    expect(zoneCity('America/Argentina/Buenos_Aires'), 'Buenos Aires');
  });

  test('no city for an id with no slash or an Etc zone', () {
    expect(zoneCity('UTC'), isNull);
    expect(zoneCity('GMT'), isNull);
    expect(zoneCity(''), isNull);
    expect(zoneCity('Etc/GMT+5'), isNull);
    expect(zoneCity('Etc/UTC'), isNull);
  });

  test('no city for an empty last segment', () {
    expect(zoneCity('Europe/'), isNull);
  });
}
