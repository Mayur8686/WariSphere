/// One halt of the palkhi (and of the pilgrims walking it).
class RouteStop {
  const RouteStop({
    required this.id,
    required this.day,
    required this.name,
    required this.dateLabel,
    required this.distanceFromStartKm,
    required this.description,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final int day; // day of the wari
  final String name;
  final String dateLabel; // indicative calendar date, e.g. "18 Jun"
  final double distanceFromStartKm;
  final String description;
  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'day': day,
        'name': name,
        'dateLabel': dateLabel,
        'distanceFromStartKm': distanceFromStartKm,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory RouteStop.fromJson(Map<String, dynamic> json) => RouteStop(
        id: json['id'] as String,
        day: json['day'] as int,
        name: json['name'] as String,
        dateLabel: json['dateLabel'] as String,
        distanceFromStartKm: (json['distanceFromStartKm'] as num).toDouble(),
        description: json['description'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );
}

/// The Wari route: Dehu/Alandi → Pandharpur.
class WariRoute {
  const WariRoute({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.totalKm,
    required this.totalDays,
    required this.stops,
  });

  final String id;
  final String title;
  final String subtitle;
  final double totalKm;
  final int totalDays;
  final List<RouteStop> stops;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'totalKm': totalKm,
        'totalDays': totalDays,
        'stops': stops.map((RouteStop s) => s.toJson()).toList(),
      };

  factory WariRoute.fromJson(Map<String, dynamic> json) => WariRoute(
        id: json['id'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        totalKm: (json['totalKm'] as num).toDouble(),
        totalDays: json['totalDays'] as int,
        stops: (json['stops'] as List<dynamic>)
            .map((dynamic e) => RouteStop.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
