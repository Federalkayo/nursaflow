import 'package:flutter_test/flutter_test.dart';
import 'package:nursaflow/features/document/models/resource.dart';

void main() {
  group('YoutubeResource.fromMap', () {
    test('parses a fully populated map', () {
      final r = YoutubeResource.fromMap({
        'videoId': 'abc123',
        'title': 'Renal Physiology Explained',
        'channelTitle': 'NurseEd',
        'thumbnailUrl': 'https://img.example/abc123.jpg',
        'embeddable': false,
        'duration': '14 min',
      });

      expect(r.videoId, 'abc123');
      expect(r.title, 'Renal Physiology Explained');
      expect(r.embeddable, false);
      expect(r.watchUrl, 'https://www.youtube.com/watch?v=abc123');
    });

    test('falls back to safe defaults when fields are missing', () {
      final r = YoutubeResource.fromMap(const {});
      expect(r.videoId, '');
      expect(r.title, 'Untitled');
      // embeddable defaults to true so pre-existing cached documents
      // aren't wrongly treated as external-only.
      expect(r.embeddable, true);
      expect(r.duration, '');
    });
  });

  group('BookResource.fromMap', () {
    test('parses a fully populated map', () {
      final b = BookResource.fromMap({
        'title': 'Fundamentals of Nursing',
        'authors': 'Potter, Perry',
        'thumbnailUrl': 'https://img.example/book.jpg',
        'infoLink': 'https://books.example/1',
      });
      expect(b.title, 'Fundamentals of Nursing');
      expect(b.authors, 'Potter, Perry');
    });

    test('falls back to safe defaults when fields are missing', () {
      final b = BookResource.fromMap(const {});
      expect(b.title, 'Untitled');
      expect(b.authors, '');
    });
  });

  group('MedlineResource.fromMap', () {
    test('falls back to safe defaults when fields are missing', () {
      final m = MedlineResource.fromMap(const {});
      expect(m.title, 'MedlinePlus Topic');
      expect(m.url, '');
      expect(m.snippet, '');
    });
  });

  group('DocumentResources.fromMap', () {
    test('isEmpty is true when all three lists are empty', () {
      final r = DocumentResources.fromMap(const {});
      expect(r.isEmpty, true);
    });

    test('isEmpty is false if any single list has an item', () {
      final r = DocumentResources.fromMap({
        'youtube': [],
        'books': [
          {'title': 'Some Book'}
        ],
        'medline': [],
      });
      expect(r.isEmpty, false);
      expect(r.books, hasLength(1));
    });

    test('ignores a field that is not a List instead of crashing', () {
      // Defends against a malformed/partial Cloud Function response where
      // e.g. "youtube" comes back as a Map or a string instead of a List.
      final r = DocumentResources.fromMap({
        'youtube': 'not-a-list',
        'books': null,
        'medline': [
          {'title': 'Diabetes', 'url': 'https://medlineplus.gov/diabetes'}
        ],
      });
      expect(r.youtube, isEmpty);
      expect(r.books, isEmpty);
      expect(r.medline, hasLength(1));
    });
  });
}