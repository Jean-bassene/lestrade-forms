import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In fr, this message translates to:
  /// **'Lestrade Forms'**
  String get appTitle;

  /// No description provided for @refresh.
  ///
  /// In fr, this message translates to:
  /// **'Actualiser'**
  String get refresh;

  /// No description provided for @cancel.
  ///
  /// In fr, this message translates to:
  /// **'Annuler'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer'**
  String get save;

  /// No description provided for @ok.
  ///
  /// In fr, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @import.
  ///
  /// In fr, this message translates to:
  /// **'Importer'**
  String get import;

  /// No description provided for @synchronize.
  ///
  /// In fr, this message translates to:
  /// **'Synchroniser'**
  String get synchronize;

  /// No description provided for @language.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get language;

  /// No description provided for @navHome.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// No description provided for @navSurveys.
  ///
  /// In fr, this message translates to:
  /// **'Enquêtes'**
  String get navSurveys;

  /// No description provided for @navResponses.
  ///
  /// In fr, this message translates to:
  /// **'Réponses'**
  String get navResponses;

  /// No description provided for @navScanner.
  ///
  /// In fr, this message translates to:
  /// **'Scanner'**
  String get navScanner;

  /// No description provided for @navSettings.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get navSettings;

  /// No description provided for @statusChecking.
  ///
  /// In fr, this message translates to:
  /// **'Vérification...'**
  String get statusChecking;

  /// No description provided for @statusWifi.
  ///
  /// In fr, this message translates to:
  /// **'WiFi connecté'**
  String get statusWifi;

  /// No description provided for @statusBasket.
  ///
  /// In fr, this message translates to:
  /// **'Mode panier — fonctionne sur tout réseau'**
  String get statusBasket;

  /// No description provided for @statusOffline.
  ///
  /// In fr, this message translates to:
  /// **'Non connecté — scannez un QR pour configurer'**
  String get statusOffline;

  /// No description provided for @scanQrToStart.
  ///
  /// In fr, this message translates to:
  /// **'Scannez un QR de questionnaire pour démarrer'**
  String get scanQrToStart;

  /// No description provided for @labelSurveys.
  ///
  /// In fr, this message translates to:
  /// **'Enquêtes'**
  String get labelSurveys;

  /// No description provided for @labelPending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get labelPending;

  /// No description provided for @quickActions.
  ///
  /// In fr, this message translates to:
  /// **'Actions rapides'**
  String get quickActions;

  /// No description provided for @syncResponses.
  ///
  /// In fr, this message translates to:
  /// **'Synchroniser les réponses'**
  String get syncResponses;

  /// No description provided for @pendingToSend.
  ///
  /// In fr, this message translates to:
  /// **'{count} réponse(s) offline à envoyer'**
  String pendingToSend(int count);

  /// No description provided for @allSynced.
  ///
  /// In fr, this message translates to:
  /// **'Tout est synchronisé'**
  String get allSynced;

  /// No description provided for @downloadSurveys.
  ///
  /// In fr, this message translates to:
  /// **'Télécharger les enquêtes'**
  String get downloadSurveys;

  /// No description provided for @downloadFromWifi.
  ///
  /// In fr, this message translates to:
  /// **'Récupère la liste depuis le serveur WiFi'**
  String get downloadFromWifi;

  /// No description provided for @useQrScanner.
  ///
  /// In fr, this message translates to:
  /// **'Utilisez le Scanner QR (pas de WiFi)'**
  String get useQrScanner;

  /// No description provided for @newEntry.
  ///
  /// In fr, this message translates to:
  /// **'Nouvelle saisie'**
  String get newEntry;

  /// No description provided for @fillForm.
  ///
  /// In fr, this message translates to:
  /// **'Remplir un formulaire'**
  String get fillForm;

  /// No description provided for @surveysDownloaded.
  ///
  /// In fr, this message translates to:
  /// **'{count} questionnaire(s) téléchargé(s)'**
  String surveysDownloaded(int count);

  /// No description provided for @noConnection.
  ///
  /// In fr, this message translates to:
  /// **'Pas de connexion — vérifiez le réseau WiFi ou le panier'**
  String get noConnection;

  /// No description provided for @surveysTitle.
  ///
  /// In fr, this message translates to:
  /// **'Enquêtes'**
  String get surveysTitle;

  /// No description provided for @noSurveysAvailable.
  ///
  /// In fr, this message translates to:
  /// **'Aucune enquête disponible'**
  String get noSurveysAvailable;

  /// No description provided for @scanOrDownload.
  ///
  /// In fr, this message translates to:
  /// **'Scannez un QR code ou téléchargez\ndepuis l\'accueil'**
  String get scanOrDownload;

  /// No description provided for @deleteQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer ?'**
  String get deleteQuestion;

  /// No description provided for @deleteSurveyConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer \"{name}\" et ses réponses offline ?'**
  String deleteSurveyConfirm(String name);

  /// No description provided for @sectionQuestionCount.
  ///
  /// In fr, this message translates to:
  /// **'{sections} section(s) • {questions} question(s)'**
  String sectionQuestionCount(int sections, int questions);

  /// No description provided for @responsesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Réponses'**
  String get responsesTitle;

  /// No description provided for @questionnaire.
  ///
  /// In fr, this message translates to:
  /// **'Questionnaire'**
  String get questionnaire;

  /// No description provided for @noResponses.
  ///
  /// In fr, this message translates to:
  /// **'Aucune réponse'**
  String get noResponses;

  /// No description provided for @deleteResponseConfirm.
  ///
  /// In fr, this message translates to:
  /// **'Supprimer cette réponse localement ?'**
  String get deleteResponseConfirm;

  /// No description provided for @pendingSync.
  ///
  /// In fr, this message translates to:
  /// **'En attente de synchronisation'**
  String get pendingSync;

  /// No description provided for @synced.
  ///
  /// In fr, this message translates to:
  /// **'Synchronisée'**
  String get synced;

  /// No description provided for @pending.
  ///
  /// In fr, this message translates to:
  /// **'En attente'**
  String get pending;

  /// No description provided for @resend.
  ///
  /// In fr, this message translates to:
  /// **'Renvoyer'**
  String get resend;

  /// No description provided for @markedForResend.
  ///
  /// In fr, this message translates to:
  /// **'Réponse marquée à renvoyer'**
  String get markedForResend;

  /// No description provided for @responseNumber.
  ///
  /// In fr, this message translates to:
  /// **'Réponse {number}'**
  String responseNumber(int number);

  /// No description provided for @scannerTitle.
  ///
  /// In fr, this message translates to:
  /// **'Scanner'**
  String get scannerTitle;

  /// No description provided for @enterUidManuallyTooltip.
  ///
  /// In fr, this message translates to:
  /// **'Saisir UID manuellement'**
  String get enterUidManuallyTooltip;

  /// No description provided for @scanSurveyQr.
  ///
  /// In fr, this message translates to:
  /// **'Scanner un QR code de questionnaire'**
  String get scanSurveyQr;

  /// No description provided for @qrShownInDesktop.
  ///
  /// In fr, this message translates to:
  /// **'Le QR code est affiché dans l\'application Desktop'**
  String get qrShownInDesktop;

  /// No description provided for @startScanner.
  ///
  /// In fr, this message translates to:
  /// **'Démarrer le scanner'**
  String get startScanner;

  /// No description provided for @enterUidManually.
  ///
  /// In fr, this message translates to:
  /// **'Saisir un UID manuellement'**
  String get enterUidManually;

  /// No description provided for @serverConfigured.
  ///
  /// In fr, this message translates to:
  /// **'Serveur configuré'**
  String get serverConfigured;

  /// No description provided for @serverAddressSaved.
  ///
  /// In fr, this message translates to:
  /// **'L\'adresse du serveur a été enregistrée automatiquement.'**
  String get serverAddressSaved;

  /// No description provided for @surveyDetected.
  ///
  /// In fr, this message translates to:
  /// **'Questionnaire détecté'**
  String get surveyDetected;

  /// No description provided for @importSurveyQuestion.
  ///
  /// In fr, this message translates to:
  /// **'Voulez-vous importer ce questionnaire depuis le serveur ?'**
  String get importSurveyQuestion;

  /// No description provided for @uidLabel.
  ///
  /// In fr, this message translates to:
  /// **'UID : {uid}'**
  String uidLabel(String uid);

  /// No description provided for @importing.
  ///
  /// In fr, this message translates to:
  /// **'Importation en cours...'**
  String get importing;

  /// No description provided for @surveyImported.
  ///
  /// In fr, this message translates to:
  /// **'Questionnaire \"{name}\" importé !'**
  String surveyImported(String name);

  /// No description provided for @enter.
  ///
  /// In fr, this message translates to:
  /// **'Saisir'**
  String get enter;

  /// No description provided for @importError.
  ///
  /// In fr, this message translates to:
  /// **'Erreur lors de l\'importation : {error}'**
  String importError(String error);

  /// No description provided for @uidNotFound.
  ///
  /// In fr, this message translates to:
  /// **'UID introuvable dans le QR'**
  String get uidNotFound;

  /// No description provided for @qrNotRecognized.
  ///
  /// In fr, this message translates to:
  /// **'QR code non reconnu'**
  String get qrNotRecognized;

  /// No description provided for @enterUidTitle.
  ///
  /// In fr, this message translates to:
  /// **'Saisir un UID'**
  String get enterUidTitle;

  /// No description provided for @stopScanner.
  ///
  /// In fr, this message translates to:
  /// **'Arrêter'**
  String get stopScanner;

  /// No description provided for @pointCameraAtQr.
  ///
  /// In fr, this message translates to:
  /// **'Pointez la caméra sur le QR code'**
  String get pointCameraAtQr;

  /// No description provided for @settingsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Paramètres'**
  String get settingsTitle;

  /// No description provided for @serverConnection.
  ///
  /// In fr, this message translates to:
  /// **'Connexion serveur'**
  String get serverConnection;

  /// No description provided for @notConfigured.
  ///
  /// In fr, this message translates to:
  /// **'Non configuré — scannez le QR du coordinateur'**
  String get notConfigured;

  /// No description provided for @testConnection.
  ///
  /// In fr, this message translates to:
  /// **'Tester la connexion'**
  String get testConnection;

  /// No description provided for @serverAccessible.
  ///
  /// In fr, this message translates to:
  /// **'Serveur accessible !'**
  String get serverAccessible;

  /// No description provided for @cannotReachServer.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de joindre le serveur'**
  String get cannotReachServer;

  /// No description provided for @configureManually.
  ///
  /// In fr, this message translates to:
  /// **'Configurer manuellement'**
  String get configureManually;

  /// No description provided for @coordinatorIpHelper.
  ///
  /// In fr, this message translates to:
  /// **'IP du PC coordinateur (port 8765 ajouté auto)'**
  String get coordinatorIpHelper;

  /// No description provided for @addressSaved.
  ///
  /// In fr, this message translates to:
  /// **'Adresse enregistrée'**
  String get addressSaved;

  /// No description provided for @aboutTitle.
  ///
  /// In fr, this message translates to:
  /// **'À propos'**
  String get aboutTitle;

  /// No description provided for @aboutDesc.
  ///
  /// In fr, this message translates to:
  /// **'Lestrade Forms — Application de collecte terrain'**
  String get aboutDesc;

  /// No description provided for @version.
  ///
  /// In fr, this message translates to:
  /// **'Version 1.2.0'**
  String get version;

  /// No description provided for @aboutFeatures.
  ///
  /// In fr, this message translates to:
  /// **'Collecte offline · Sync réseau local · Analyse Desktop'**
  String get aboutFeatures;

  /// No description provided for @formTitle.
  ///
  /// In fr, this message translates to:
  /// **'Formulaire'**
  String get formTitle;

  /// No description provided for @surveyNotFound.
  ///
  /// In fr, this message translates to:
  /// **'Questionnaire introuvable'**
  String get surveyNotFound;

  /// No description provided for @acquiringGps.
  ///
  /// In fr, this message translates to:
  /// **'Acquisition GPS...'**
  String get acquiringGps;

  /// No description provided for @gpsAcquired.
  ///
  /// In fr, this message translates to:
  /// **'GPS acquis (±{accuracy} m)'**
  String gpsAcquired(String accuracy);

  /// No description provided for @gpsUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'GPS indisponible'**
  String get gpsUnavailable;

  /// No description provided for @responseSavedOffline.
  ///
  /// In fr, this message translates to:
  /// **'Réponse enregistrée (offline)'**
  String get responseSavedOffline;

  /// No description provided for @requiredFields.
  ///
  /// In fr, this message translates to:
  /// **'Champs requis : {fields}'**
  String requiredFields(String fields);

  /// No description provided for @saveResponse.
  ///
  /// In fr, this message translates to:
  /// **'Enregistrer la réponse'**
  String get saveResponse;

  /// No description provided for @selectDate.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionner une date'**
  String get selectDate;

  /// No description provided for @noOptionsDefined.
  ///
  /// In fr, this message translates to:
  /// **'(aucune option définie)'**
  String get noOptionsDefined;

  /// No description provided for @emailHint.
  ///
  /// In fr, this message translates to:
  /// **'exemple@email.com'**
  String get emailHint;

  /// No description provided for @phoneHint.
  ///
  /// In fr, this message translates to:
  /// **'+243...'**
  String get phoneHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
