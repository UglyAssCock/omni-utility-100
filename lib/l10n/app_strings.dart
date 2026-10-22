class AppStrings {
  static bool isArabic = false;

  static String tr(String en, String ar) => isArabic ? ar : en;

  static Map<String, String> categoryTitle(String catId) {
    switch (catId) {
      case 'all':
        return {'en': 'All (100)', 'ar': 'الكل (100)'};
      case 'fav':
        return {'en': 'Favorites', 'ar': 'المفضلة'};
      case 'pdf':
        return {'en': 'PDF Tools (14)', 'ar': 'أدوات PDF (14)'};
      case 'scanner':
        return {'en': 'Scanner (6)', 'ar': 'الماسح الضوئي (6)'};
      case 'qr':
        return {'en': 'QR & Barcode (7)', 'ar': 'رموز QR والباركود (7)'};
      case 'units':
        return {'en': 'Unit Converters (12)', 'ar': 'تحويل الوحدات (12)'};
      case 'files':
        return {'en': 'File Converters (7)', 'ar': 'تحويل الملفات (7)'};
      case 'random':
        return {'en': 'Random & Games (11)', 'ar': 'عشوائيات وألعاب (11)'};
      case 'time':
        return {'en': 'Time Tools (10)', 'ar': 'أدوات الوقت (10)'};
      case 'calc':
        return {'en': 'Calculators (10)', 'ar': 'الحاسبات (10)'};
      case 'phone':
        return {'en': 'Phone Utilities (10)', 'ar': 'أدوات الهاتف (10)'};
      case 'text':
        return {'en': 'Text & Dev (7)', 'ar': 'نصوص ومطورين (7)'};
      case 'app':
        return {'en': 'App & System (6)', 'ar': 'إعدادات النظام (6)'};
      default:
        return {'en': catId, 'ar': catId};
    }
  }

  static String cat(String catId) {
    final map = categoryTitle(catId);
    return isArabic ? (map['ar'] ?? catId) : (map['en'] ?? catId);
  }
}
