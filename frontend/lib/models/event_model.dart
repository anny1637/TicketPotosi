class EventModel {
  final int id;
  final String title;
  final String description;
  final String location;
  final String eventDate;
  final String? image;
  final String? video;
  final String? organizer;
  final String? organizerLogo;
  final String? category;
  final String status;
  final int capacity;
  final int ticketsAvailable;
  final List<dynamic> ticketTypes;
  final List<dynamic> artists;
  final Map<String, dynamic>? presale;
  final bool? isPresale;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.eventDate,
    this.image,
    this.video,
    this.organizer,
    this.organizerLogo,
    this.category,
    required this.status,
    required this.capacity,
    required this.ticketsAvailable,
    required this.ticketTypes,
    required this.artists,
    this.presale,
    this.isPresale,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    // Detectar si hay algún tipo en preventa
    final types = (json['ticket_types'] as List?) ?? [];
    final hasPresale = types.any((t) => t['is_presale'] == true);

    final int rawId = json['id'] is int
        ? json['id'] as int
        : (int.tryParse(json['id']?.toString() ?? '') ?? 0);

    final int rawCapacity = json['capacity'] is int
        ? json['capacity'] as int
        : (int.tryParse(json['capacity']?.toString() ?? '') ?? 0);

    final int rawTicketsAvailable = json['tickets_available'] is int
        ? json['tickets_available'] as int
        : (int.tryParse(json['tickets_available']?.toString() ?? '') ?? 0);

    return EventModel(
      id:               rawId,
      title:            json['title'] ?? '',
      description:      json['description'] ?? '',
      location:         json['location'] ?? '',
      eventDate:        json['event_date'] ?? '',
      image:            json['image'],
      video:            json['video'],
      organizer:        json['organizer'],
      organizerLogo:    json['organizer_logo'],
      category:         json['category'],
      status:           json['status'] ?? 'active',
      capacity:         rawCapacity,
      ticketsAvailable: rawTicketsAvailable,
      ticketTypes:      types,
      artists:          (json['artists'] as List?) ?? [],
      presale:          json['presale'] as Map<String, dynamic>?,
      isPresale:        hasPresale,
    );
  }
}