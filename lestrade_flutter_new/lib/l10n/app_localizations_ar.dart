// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'Lestrade Forms';

  @override
  String get refresh => 'تحديث';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get save => 'حفظ';

  @override
  String get ok => 'موافق';

  @override
  String get import => 'استيراد';

  @override
  String get synchronize => 'مزامنة';

  @override
  String get language => 'اللغة';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navSurveys => 'استطلاعات';

  @override
  String get navResponses => 'إجابات';

  @override
  String get navScanner => 'مسح';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get statusChecking => 'جارٍ التحقق...';

  @override
  String get statusWifi => 'WiFi متصل';

  @override
  String get statusBasket => 'وضع السلة — يعمل على أي شبكة';

  @override
  String get statusOffline => 'غير متصل — امسح رمز QR للتهيئة';

  @override
  String get scanQrToStart => 'امسح رمز QR لبدء الاستخدام';

  @override
  String get labelSurveys => 'استطلاعات';

  @override
  String get labelPending => 'قيد الانتظار';

  @override
  String get quickActions => 'إجراءات سريعة';

  @override
  String get syncResponses => 'مزامنة الإجابات';

  @override
  String pendingToSend(int count) {
    return '$count إجابة في وضع غير متصل للإرسال';
  }

  @override
  String get allSynced => 'كل شيء تمت مزامنته';

  @override
  String get downloadSurveys => 'تنزيل الاستطلاعات';

  @override
  String get downloadFromWifi => 'يجلب القائمة من خادم WiFi';

  @override
  String get useQrScanner => 'استخدم ماسح QR (بدون WiFi)';

  @override
  String get newEntry => 'إدخال جديد';

  @override
  String get fillForm => 'ملء استمارة';

  @override
  String surveysDownloaded(int count) {
    return 'تم تنزيل $count استطلاع';
  }

  @override
  String get noConnection => 'لا يوجد اتصال — تحقق من WiFi أو السلة';

  @override
  String get surveysTitle => 'الاستطلاعات';

  @override
  String get noSurveysAvailable => 'لا توجد استطلاعات';

  @override
  String get scanOrDownload => 'امسح رمز QR أو نزّل\nمن الرئيسية';

  @override
  String get deleteQuestion => 'حذف؟';

  @override
  String deleteSurveyConfirm(String name) {
    return 'حذف \"$name\" وإجاباته غير المتصلة؟';
  }

  @override
  String sectionQuestionCount(int sections, int questions) {
    return '$sections قسم • $questions سؤال';
  }

  @override
  String get responsesTitle => 'الإجابات';

  @override
  String get questionnaire => 'استطلاع';

  @override
  String get noResponses => 'لا توجد إجابات';

  @override
  String get deleteResponseConfirm => 'حذف هذه الإجابة محلياً؟';

  @override
  String get pendingSync => 'في انتظار المزامنة';

  @override
  String get synced => 'تمت المزامنة';

  @override
  String get pending => 'قيد الانتظار';

  @override
  String get resend => 'إعادة إرسال';

  @override
  String get markedForResend => 'تم تعليم الإجابة لإعادة الإرسال';

  @override
  String responseNumber(int number) {
    return 'إجابة $number';
  }

  @override
  String get scannerTitle => 'الماسح';

  @override
  String get enterUidManuallyTooltip => 'إدخال UID يدوياً';

  @override
  String get scanSurveyQr => 'مسح رمز QR للاستطلاع';

  @override
  String get qrShownInDesktop => 'رمز QR معروض في تطبيق سطح المكتب';

  @override
  String get startScanner => 'بدء المسح';

  @override
  String get enterUidManually => 'إدخال UID يدوياً';

  @override
  String get serverConfigured => 'تم تهيئة الخادم';

  @override
  String get serverAddressSaved => 'تم حفظ عنوان الخادم تلقائياً.';

  @override
  String get surveyDetected => 'تم اكتشاف استطلاع';

  @override
  String get importSurveyQuestion => 'هل تريد استيراد هذا الاستطلاع من الخادم؟';

  @override
  String uidLabel(String uid) {
    return 'UID: $uid';
  }

  @override
  String get importing => 'جارٍ الاستيراد...';

  @override
  String surveyImported(String name) {
    return 'تم استيراد الاستطلاع \"$name\"!';
  }

  @override
  String get enter => 'ملء';

  @override
  String importError(String error) {
    return 'خطأ في الاستيراد: $error';
  }

  @override
  String get uidNotFound => 'لم يُوجد UID في رمز QR';

  @override
  String get qrNotRecognized => 'رمز QR غير معروف';

  @override
  String get enterUidTitle => 'إدخال UID';

  @override
  String get stopScanner => 'إيقاف';

  @override
  String get pointCameraAtQr => 'وجّه الكاميرا نحو رمز QR';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get serverConnection => 'اتصال الخادم';

  @override
  String get notConfigured => 'غير مهيأ — امسح QR المنسق';

  @override
  String get testConnection => 'اختبار الاتصال';

  @override
  String get serverAccessible => 'الخادم متاح!';

  @override
  String get cannotReachServer => 'تعذّر الوصول إلى الخادم';

  @override
  String get configureManually => 'التهيئة اليدوية';

  @override
  String get coordinatorIpHelper =>
      'IP جهاز المنسق (يُضاف المنفذ 8765 تلقائياً)';

  @override
  String get addressSaved => 'تم حفظ العنوان';

  @override
  String get aboutTitle => 'حول';

  @override
  String get aboutDesc => 'Lestrade Forms — تطبيق جمع البيانات الميداني';

  @override
  String get version => 'الإصدار 1.2.0';

  @override
  String get aboutFeatures => 'جمع بلا اتصال · مزامنة محلية · تحليل سطح المكتب';

  @override
  String get formTitle => 'الاستمارة';

  @override
  String get surveyNotFound => 'الاستطلاع غير موجود';

  @override
  String get acquiringGps => 'جارٍ الحصول على GPS...';

  @override
  String gpsAcquired(String accuracy) {
    return 'تم الحصول على GPS (±$accuracy م)';
  }

  @override
  String get gpsUnavailable => 'GPS غير متاح';

  @override
  String get responseSavedOffline => 'تم حفظ الإجابة (بلا اتصال)';

  @override
  String requiredFields(String fields) {
    return 'الحقول المطلوبة: $fields';
  }

  @override
  String get saveResponse => 'حفظ الإجابة';

  @override
  String get selectDate => 'اختر تاريخاً';

  @override
  String get noOptionsDefined => '(لم تُحدد خيارات)';

  @override
  String get emailHint => 'مثال@بريد.com';

  @override
  String get phoneHint => '+...';
}
