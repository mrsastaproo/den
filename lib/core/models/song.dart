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
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      album: json['album'] ?? '',
      image: json['image'] ?? '',
      url: json['url'] ?? '',
      duration: json['duration']?.toString() ?? '0',
      year: json['year']?.toString() ?? '',
      language: json['language'] ?? '',
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
    title: json['name'] ?? '',
    artist: artistName,
    album: json['album']?['name'] ?? '',
    image: image,
    url: '',
    duration: json['duration']?.toString() ?? '0',
    year: json['year']?.toString() ?? '',
    language: json['language'] ?? '',
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
  };
}