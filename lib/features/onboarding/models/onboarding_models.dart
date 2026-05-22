class OnboardingData {
  String fullName;
  String phone;
  String gender;
  int age;
  String professionalStatus;
  String city;
  String mainLine;
  String secondaryLine;
  String otherLine;
  String boardingStation;
  String waitingTime;
  String travelTime;
  String usageTime;
  bool ticketIssues;
  String paymentMethod;

  OnboardingData({
    this.fullName = '',
    this.phone = '',
    this.gender = '',
    this.age = 0,
    this.professionalStatus = '',
    this.city = '',
    this.mainLine = '',
    this.secondaryLine = '',
    this.otherLine = '',
    this.boardingStation = '',
    this.waitingTime = '',
    this.travelTime = '',
    this.usageTime = '',
    this.ticketIssues = false,
    this.paymentMethod = '',
  });

  Map<String, dynamic> toProfileMap() {
    return {
      'fullName': fullName,
      'phone': phone,
      'gender': gender,
      'age': age,
      'professionalStatus': professionalStatus,
      'city': city,
      'onboardingCompleted': true,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toTransportHabitsMap() {
    return {
      'mainLine': mainLine,
      'secondaryLine': secondaryLine,
      'otherLine': otherLine,
      'boardingStation': boardingStation,
      'waitingTime': waitingTime,
      'travelTime': travelTime,
      'usageTime': usageTime,
      'ticketIssues': ticketIssues,
      'paymentMethod': paymentMethod,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  bool get isProfileComplete =>
      fullName.isNotEmpty &&
      phone.isNotEmpty &&
      gender.isNotEmpty &&
      age > 0 &&
      professionalStatus.isNotEmpty &&
      city.isNotEmpty;

  bool get isTransportComplete =>
      mainLine.isNotEmpty &&
      waitingTime.isNotEmpty &&
      travelTime.isNotEmpty &&
      usageTime.isNotEmpty &&
      paymentMethod.isNotEmpty;
}

class ProfessionalStatus {
  static const List<String> options = [
    'طالب',
    'موظف',
    'عامل',
    'عمل جزئي',
    'بدون عمل',
  ];

  static const List<String> optionsEn = [
    'Student',
    'Employee',
    'Worker',
    'Part-time',
    'Unemployed',
  ];

  static const List<String> optionsFr = [
    'Étudiant',
    'Employé',
    'Ouvrier',
    'Temps partiel',
    'Sans emploi',
  ];
}
