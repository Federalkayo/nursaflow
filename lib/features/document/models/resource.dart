import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class YoutubeResource {
  const YoutubeResource({
    required this.videoId,
    required this.title,
    required this.channelTitle,
    required this.thumbnailUrl,
  });

  final String videoId;
  final String title;
  final String channelTitle;
  final String thumbnailUrl;

  String get watchUrl => 'https://www.youtube.com/watch?v=$videoId';

  factory YoutubeResource.fromMap(Map<String, dynamic> map) {
    return YoutubeResource(
      videoId: map['videoId']?.toString() ?? '',
      title: map['title']?.toString() ?? 'Untitled',
      channelTitle: map['channelTitle']?.toString() ?? '',
      thumbnailUrl: map['thumbnailUrl']?.toString() ?? '',
    );
  }
}

class BookResource {
  const BookResource({
    required this.title,
    required this.authors,
    required this.thumbnailUrl,
    required this.infoLink,
  });

  final String title;
  final String authors;
  final String thumbnailUrl;
  final String infoLink;

  factory BookResource.fromMap(Map<String, dynamic> map) {
    return BookResource(
      title: map['title']?.toString() ?? 'Untitled',
      authors: map['authors']?.toString() ?? '',
      thumbnailUrl: map['thumbnailUrl']?.toString() ?? '',
      infoLink: map['infoLink']?.toString() ?? '',
    );
  }
}

class MedlineResource {
  const MedlineResource({
    required this.title,
    required this.url,
    required this.snippet,
  });

  final String title;
  final String url;
  final String snippet;

  factory MedlineResource.fromMap(Map<String, dynamic> map) {
    return MedlineResource(
      title: map['title']?.toString() ?? 'MedlinePlus Topic',
      url: map['url']?.toString() ?? '',
      snippet: map['snippet']?.toString() ?? '',
    );
  }
}

class DocumentResources {
  const DocumentResources({
    required this.youtube,
    required this.books,
    required this.medline,
  });

  final List<YoutubeResource> youtube;
  final List<BookResource> books;
  final List<MedlineResource> medline;

  bool get isEmpty => youtube.isEmpty && books.isEmpty && medline.isEmpty;

  factory DocumentResources.fromMap(Map<String, dynamic> map) {
    List<T> parseList<T>(dynamic field, T Function(Map<String, dynamic>) fromMap) {
      if (field is! List) return <T>[];
      return field
          .whereType<Map>()
          .map((e) => fromMap(e.map((k, v) => MapEntry(k.toString(), v))))
          .toList();
    }

    return DocumentResources(
      youtube: parseList(map['youtube'], YoutubeResource.fromMap),
      books: parseList(map['books'], BookResource.fromMap),
      medline: parseList(map['medline'], MedlineResource.fromMap),
    );
  }
}

/// Calls the fetchResources Cloud Function, which looks up YouTube lectures,
/// Google Books references, and MedlinePlus topics for the document and
/// caches the combined result server-side on the document itself. This
/// provider just triggers that call per documentId — autoDispose so it
/// doesn't hold onto a family entry for every document a student has ever
/// opened for the life of the app session.
final documentResourcesProvider =
    FutureProvider.autoDispose.family<DocumentResources, String>((ref, documentId) async {
  final result = await FirebaseFunctions.instance
      .httpsCallable('fetchResources')
      .call(<String, dynamic>{'documentId': documentId});
  final data = Map<String, dynamic>.from(result.data as Map);
  return DocumentResources.fromMap(data);
});