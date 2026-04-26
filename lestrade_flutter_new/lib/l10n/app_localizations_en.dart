// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Lestrade Forms';

  @override
  String get refresh => 'Refresh';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get ok => 'OK';

  @override
  String get import => 'Import';

  @override
  String get synchronize => 'Sync';

  @override
  String get language => 'Language';

  @override
  String get navHome => 'Home';

  @override
  String get navSurveys => 'Surveys';

  @override
  String get navResponses => 'Responses';

  @override
  String get navScanner => 'Scanner';

  @override
  String get navSettings => 'Settings';

  @override
  String get statusChecking => 'Checking...';

  @override
  String get statusWifi => 'WiFi connected';

  @override
  String get statusBasket => 'Basket mode — works on any network';

  @override
  String get statusOffline => 'Not connected — scan a QR to configure';

  @override
  String get scanQrToStart => 'Scan a survey QR code to get started';

  @override
  String get labelSurveys => 'Surveys';

  @override
  String get labelPending => 'Pending';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get syncResponses => 'Sync responses';

  @override
  String pendingToSend(int count) {
    return '$count offline response(s) to send';
  }

  @override
  String get allSynced => 'Everything is synced';

  @override
  String get downloadSurveys => 'Download surveys';

  @override
  String get downloadFromWifi => 'Fetches list from WiFi server';

  @override
  String get useQrScanner => 'Use QR Scanner (no WiFi)';

  @override
  String get newEntry => 'New entry';

  @override
  String get fillForm => 'Fill a form';

  @override
  String surveysDownloaded(int count) {
    return '$count survey(s) downloaded';
  }

  @override
  String get noConnection => 'No connection — check WiFi or basket';

  @override
  String get surveysTitle => 'Surveys';

  @override
  String get noSurveysAvailable => 'No surveys available';

  @override
  String get scanOrDownload => 'Scan a QR code or download\nfrom home';

  @override
  String get deleteQuestion => 'Delete?';

  @override
  String deleteSurveyConfirm(String name) {
    return 'Delete \"$name\" and its offline responses?';
  }

  @override
  String sectionQuestionCount(int sections, int questions) {
    return '$sections section(s) • $questions question(s)';
  }

  @override
  String get responsesTitle => 'Responses';

  @override
  String get questionnaire => 'Survey';

  @override
  String get noResponses => 'No responses';

  @override
  String get deleteResponseConfirm => 'Delete this response locally?';

  @override
  String get pendingSync => 'Pending sync';

  @override
  String get synced => 'Synced';

  @override
  String get pending => 'Pending';

  @override
  String get resend => 'Resend';

  @override
  String get markedForResend => 'Response marked for resend';

  @override
  String responseNumber(int number) {
    return 'Response $number';
  }

  @override
  String get scannerTitle => 'Scanner';

  @override
  String get enterUidManuallyTooltip => 'Enter UID manually';

  @override
  String get scanSurveyQr => 'Scan a survey QR code';

  @override
  String get qrShownInDesktop => 'QR code is shown in the Desktop app';

  @override
  String get startScanner => 'Start scanner';

  @override
  String get enterUidManually => 'Enter a UID manually';

  @override
  String get serverConfigured => 'Server configured';

  @override
  String get serverAddressSaved => 'Server address saved automatically.';

  @override
  String get surveyDetected => 'Survey detected';

  @override
  String get importSurveyQuestion =>
      'Do you want to import this survey from the server?';

  @override
  String uidLabel(String uid) {
    return 'UID: $uid';
  }

  @override
  String get importing => 'Importing...';

  @override
  String surveyImported(String name) {
    return 'Survey \"$name\" imported!';
  }

  @override
  String get enter => 'Fill';

  @override
  String importError(String error) {
    return 'Import error: $error';
  }

  @override
  String get uidNotFound => 'UID not found in QR';

  @override
  String get qrNotRecognized => 'QR code not recognized';

  @override
  String get enterUidTitle => 'Enter a UID';

  @override
  String get stopScanner => 'Stop';

  @override
  String get pointCameraAtQr => 'Point camera at QR code';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get serverConnection => 'Server connection';

  @override
  String get notConfigured => 'Not configured — scan coordinator\'s QR';

  @override
  String get testConnection => 'Test connection';

  @override
  String get serverAccessible => 'Server accessible!';

  @override
  String get cannotReachServer => 'Cannot reach server';

  @override
  String get configureManually => 'Configure manually';

  @override
  String get coordinatorIpHelper =>
      'Coordinator PC IP (port 8765 added automatically)';

  @override
  String get addressSaved => 'Address saved';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutDesc => 'Lestrade Forms — Field data collection app';

  @override
  String get version => 'Version 1.2.0';

  @override
  String get aboutFeatures =>
      'Offline collection · Local sync · Desktop analysis';

  @override
  String get formTitle => 'Form';

  @override
  String get surveyNotFound => 'Survey not found';

  @override
  String get acquiringGps => 'Acquiring GPS...';

  @override
  String gpsAcquired(String accuracy) {
    return 'GPS acquired (±$accuracy m)';
  }

  @override
  String get gpsUnavailable => 'GPS unavailable';

  @override
  String get responseSavedOffline => 'Response saved (offline)';

  @override
  String requiredFields(String fields) {
    return 'Required fields: $fields';
  }

  @override
  String get saveResponse => 'Save response';

  @override
  String get selectDate => 'Select a date';

  @override
  String get noOptionsDefined => '(no options defined)';

  @override
  String get emailHint => 'example@email.com';

  @override
  String get phoneHint => '+1...';
}
