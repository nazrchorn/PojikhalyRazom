class Car {
  String brand;
  String model;
  int year;
  int seats;
  String? color; // Нове поле
  String? plateNumber; // Нове поле

  Car({
    required this.brand,
    required this.model,
    required this.year,
    required this.seats,
    this.color,
    this.plateNumber,
  });

  factory Car.fromMap(Map<String, dynamic> map) {
    return Car(
      brand: map['brand'] ?? '',
      model: map['model'] ?? '',
      year: map['year'] ?? 0,
      seats: map['seats'] ?? 0,
      color: map['color'],
      plateNumber: map['plateNumber'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'brand': brand,
      'model': model,
      'year': year,
      'seats': seats,
      'color': color,
      'plateNumber': plateNumber,
    };
  }
}