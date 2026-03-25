class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String image;
  final String url;
  final String duration;
  final String year;
  final String language;
  final bool isExplicit;
  final int playCount;

  Song({

    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.image,
    required this.url,
    required this.duration,
    required this.year,
    required this.language,
    required this.isExplicit,
    this.playCount = 0,
  });

  String get source {
    if (id.startsWith('jamendo_')) return 'JAMENDO';
    if (id.startsWith('audius_')) return 'AUDIUS';
    if (id.startsWith('yt_')) return 'YOUTUBE';
    return 'JIOSAAVN';
  }


  static String _sanitize(String text) {
    return text
        .replaceAll(RegExp(r'\s*-\s*JioSaavn', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*on\s*JioSaavn', caseSensitive: false), '')
        .replaceAll(RegExp(r'Saavn', caseSensitive: false), '')
        .replaceAll(RegExp(r'Audius', caseSensitive: false), '')
        .replaceAll(RegExp(r'Jamendo', caseSensitive: false), '')
        .trim();
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    // image can be a plain String URL or a List of {quality, url} objects
    String imageUrl = '';
    final rawImage = json['image'];
    if (rawImage is String) {
      imageUrl = rawImage;
    } else if (rawImage is List && rawImage.isNotEmpty) {
      // Pick the last (highest quality) entry
      final last = rawImage.last;
      if (last is Map) {
        imageUrl = (last['url'] ?? last['link'] ?? '').toString();
      }
    }
    return Song(
      id: json['id'] ?? '',
      title: _sanitize(json['title'] ?? json['name'] ?? ''),
      artist: _sanitize(json['artist'] ?? ''),
      album: _sanitize(json['album'] ?? ''),
      image: imageUrl,
      url: json['url'] ?? '',
      duration: json['duration']?.toString() ?? '0',
      year: json['year']?.toString() ?? '',
      language: json['language'] ?? '',
      isExplicit: json['isExplicit'] ?? json['explicit'] ?? false,
      playCount: json['playCount'] != null ? (int.tryParse(json['playCount'].toString()) ?? 0) : 0,
    );
  }

  factory Song.fromSumitApi(Map<String, dynamic> json) {
    // Get highest quality image
    final images = json['image'] as List?;
    final image = images != null && images.isNotEmpty
        ? (images.last['url'] ?? '')
        : '';

    // Get primary artists
    final primaryArtists = json['artists']?['primary'] as List?;
    final artistName = primaryArtists != null && primaryArtists.isNotEmpty
        ? primaryArtists.map((a) => a['name']).join(', ')
        : '';

    return Song(
      id: json['id'] ?? '',
      title: _sanitize(json['name'] ?? ''),
      artist: _sanitize(artistName),
      album: _sanitize(json['album']?['name'] ?? ''),
      image: image,
      url: '',
      duration: json['duration']?.toString() ?? '0',
      year: json['year']?.toString() ?? '',
      language: json['language'] ?? '',
      isExplicit: json['explicitContent'] == true || json['explicit'] == true,
      playCount: json['playCount'] != null ? (int.tryParse(json['playCount'].toString()) ?? 0) : 0,
    );
  }


  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'image': image,
    'url': url,
    'duration': duration,
    'year': year,
    'language': language,
    'isExplicit': isExplicit,
    'playCount': playCount,
  };
}