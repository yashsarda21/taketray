import 'package:flutter_test/flutter_test.dart';
import 'package:taketray/domain/rules/folder_names.dart';

void main() {
  test('a free name is returned as it is', () {
    expect(uniqueFolderName('Goa', {}), 'Goa');
    expect(uniqueFolderName('Goa', {'Paris'}), 'Goa');
  });

  test('a taken name gets (2)', () {
    expect(uniqueFolderName('Goa', {'Goa'}), 'Goa (2)');
  });

  test('numbering goes on past taken numbers', () {
    expect(uniqueFolderName('Goa', {'Goa', 'Goa (2)'}), 'Goa (3)');
  });

  test('a free gap is filled', () {
    expect(uniqueFolderName('Goa', {'Goa', 'Goa (3)'}), 'Goa (2)');
  });

  test('(2) alone is not a clash while the base is free', () {
    expect(uniqueFolderName('Goa', {'Goa (2)'}), 'Goa');
  });

  test('names differing only in case clash (Android folders ignore case)', () {
    expect(uniqueFolderName('Goa', {'goa'}), 'Goa (2)');
    expect(uniqueFolderName('Goa', {'GOA', 'goa (2)'}), 'Goa (3)');
  });

  test('a base that already ends in a number is just extended', () {
    expect(uniqueFolderName('Goa (2)', {'Goa (2)'}), 'Goa (2) (2)');
  });
}
