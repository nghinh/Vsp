// Matching a Vietnamese course name against what a Vietnamese golfer types.
//
// Nobody types tone marks into a search box. Every assertion here is a query
// somebody would really type and a name that really is in the database.

import 'package:flutter_test/flutter_test.dart';

import 'package:vsp_mobile/core/text/vietnamese_search.dart';

void main() {
  group('fold', () {
    test('strips tone marks and vowel modifications', () {
      expect(VietnameseSearch.fold('Long Thành'), 'long thanh');
      expect(VietnameseSearch.fold('Đồng Nai'), 'dong nai');
      expect(VietnameseSearch.fold('Sông Bé'), 'song be');
      expect(VietnameseSearch.fold('Tân Sơn Nhất'), 'tan son nhat');
      expect(VietnameseSearch.fold('Vũng Tàu'), 'vung tau');
    });

    test('handles the letter đ, which no case folding reaches', () {
      // Đ is its own letter, not a d wearing a mark, so lowercasing leaves it
      // as đ and `contains('d')` stays false.
      expect(VietnameseSearch.fold('ĐẠI LẢI'), 'dai lai');
    });

    test('leaves everything it has no rule for alone', () {
      expect(
        VietnameseSearch.fold('BRG Kings Island 18'),
        'brg kings island 18',
      );
      expect(
        VietnameseSearch.fold('FLC Hạ Long — Championship'),
        'flc ha long — championship',
      );
    });
  });

  group('matches', () {
    test('finds an accented name from an unaccented query', () {
      expect(
        VietnameseSearch.matches('Long Thành Golf Resort', 'long thanh'),
        isTrue,
      );
      expect(VietnameseSearch.matches('Sân golf Đồng Nai', 'dong nai'), isTrue);
    });

    test('finds an unaccented query typed with accents anyway', () {
      expect(VietnameseSearch.matches('Long Thanh Golf', 'Thành'), isTrue);
    });

    test('ignores case', () {
      expect(VietnameseSearch.matches('BRG Kings Island', 'kings'), isTrue);
      expect(VietnameseSearch.matches('brg kings island', 'BRG'), isTrue);
    });

    test('takes words in any order', () {
      // A golfer who remembers "Thành" first should still find the course.
      expect(
        VietnameseSearch.matches('Long Thành Golf Resort', 'thanh long'),
        isTrue,
      );
    });

    test('needs every word, not just one', () {
      expect(
        VietnameseSearch.matches('Long Thành Golf Resort', 'long da lat'),
        isFalse,
        reason:
            'da lat is not in the name; matching on "long" alone would '
            'put every Long course in front of someone looking for Đà Lạt',
      );
    });

    test('an empty query hides nothing', () {
      expect(VietnameseSearch.matches('Long Thành', ''), isTrue);
      expect(VietnameseSearch.matches('Long Thành', '   '), isTrue);
    });

    test('a query that matches nothing says so', () {
      expect(VietnameseSearch.matches('Long Thành', 'sky lake'), isFalse);
    });
  });
}
