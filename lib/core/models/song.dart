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