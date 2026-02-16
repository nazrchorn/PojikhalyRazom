class Car {
  String brand;
  String model;
  int year;
  int seats;

  Car({
    required this.brand,
    required this.model,
    required this.year,
    required this.seats,
  });

  factory Car.fromMap(Map<String, dynamic> map) {
    return Car(
      brand: map['brand'],
      model: map['model'],
      year: map['year'],
      seats: map['seats'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'brand': brand,
      'model': model,
      'year': year,
      'seats': seats,
    };
  }
}