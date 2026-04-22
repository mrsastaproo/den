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
    if (id.startsWith('sc_')) return 'SOUNDCLOUD';
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
    // 1. Robust Image Parsing (handles String URL or List of objects)
    String imageUrl = '';
    final rawImage = json['image'];
    if (rawImage is String) {
      imageUrl = rawImage;
    } else if (rawImage is List && rawImage.isNotEmpty) {
      final last = rawImage.last;
      if (last is Map) {
        imageUrl = (last['url'] ?? last['link'] ?? '').toString();
      } else if (last is String) {
        imageUrl = last;
      }
    }

    // 2. Robust Artist Parsing
    String artistName = '';
    
    // Format A: { artists: { primary: [{name: ...}] } }  (saavn.dev style)
    final artistsObj = json['artists'];
    if (artistsObj is Map) {
      final primary = artistsObj['primary'];
      if (primary is List && primary.isNotEmpty) {
        artistName = primary.map((a) => (a is Map ? a['name'] : a).toString()).join(', ');
      }
    }
    
    // Format B: { primaryArtists: [{name: ...}] }  (Vercel mirror style)
    if (artistName.isEmpty) {
      final pa = json['primaryArtists'];
      if (pa is List && pa.isNotEmpty) {
        artistName = pa
            .where((a) => a is Map && a['name'] != null)
            .map((a) => a['name'].toString())
            .join(', ');
      } else if (pa is String && pa.isNotEmpty) {
        artistName = pa;
      }
    }
    
    // Format C: simple 'artist' string
    if (artistName.isEmpty) {
      final a = json['artist'];
      if (a is String && a.isNotEmpty) artistName = a;
    }

    // 3. Fallback for album name
    final albumName = json['album'] is Map 
        ? (json['album']['name'] ?? '') 
        : (json['album'] ?? '');

    // 4. Parse explicitContent (can be bool, string '0'/'1', or int)
    final ec = json['explicitContent'] ?? json['explicit'];
    final isExplicit = ec == true || ec == 1 || ec == '1';

    return Song(
      id: json['id']?.toString() ?? '',
      title: _sanitize(json['name'] ?? json['title'] ?? 'Unknown'),
      artist: _sanitize(artistName.isEmpty ? 'Unknown Artist' : artistName),
      album: _sanitize(albumName.toString()),
      image: imageUrl,
      url: '', // Fetched on demand by PlayerService
      duration: json['duration']?.toString() ?? '0',
      year: json['year']?.toString() ?? '',
      language: json['language']?.toString() ?? '',
      isExplicit: isExplicit,
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