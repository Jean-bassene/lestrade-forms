// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Lestrade Forms';

  @override
  String get refresh => 'Actualiser';

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get save => 'Enregistrer';

  @override
  String get ok => 'OK';

  @override
  String get import => 'Importer';

  @override
  String get synchronize => 'Synchroniser';

  @override
  String get language => 'Langue';

  @override
  String get navHome => 'Accueil';

  @override
  String get navSurveys => 'Enquêtes';

  @override
  String get navResponses => 'Réponses';

  @override
  String get navScanner => 'Scanner';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get statusChecking => 'Vérification...';

  @override
  String get statusWifi => 'WiFi connecté';

  @override
  String get statusBasket => 'Mode panier — fonctionne sur tout réseau';

  @override
  String get statusOffline => 'Non connecté — scannez un QR pour configurer';

  @override
  String get scanQrToStart => 'Scannez un QR de questionnaire pour démarrer';

  @override
  String get labelSurveys => 'Enquêtes';

  @override
  String get labelPending => 'En attente';

  @override
  String get quickActions => 'Actions rapides';

  @override
  String get syncResponses => 'Synchroniser les réponses';

  @override
  String pendingToSend(int count) {
    return '$count réponse(s) offline à envoyer';
  }

  @override
  String get allSynced => 'Tout est synchronisé';

  @override
  String get downloadSurveys => 'Télécharger les enquêtes';

  @override
  String get downloadFromWifi => 'Récupère la liste depuis le serveur WiFi';

  @override
  String get useQrScanner => 'Utilisez le Scanner QR (pas de WiFi)';

  @override
  String get newEntry => 'Nouvelle saisie';

  @override
  String get fillForm => 'Remplir un formulaire';

  @override
  String surveysDownloaded(int count) {
    return '$count questionnaire(s) téléchargé(s)';
  }

  @override
  String get noConnection =>
      'Pas de connexion — vérifiez le réseau WiFi ou le panier';

  @override
  String get surveysTitle => 'Enquêtes';

  @override
  String get noSurveysAvailable => 'Aucune enquête disponible';

  @override
  String get scanOrDownload =>
      'Scannez un QR code ou téléchargez\ndepuis l\'accueil';

  @override
  String get deleteQuestion => 'Supprimer ?';

  @override
  String deleteSurveyConfirm(String name) {
    return 'Supprimer \"$name\" et ses réponses offline ?';
  }

  @override
  String sectionQuestionCount(int sections, int questions) {
    return '$sections section(s) • $questions question(s)';
  }

  @override
  String get responsesTitle => 'Réponses';

  @override
  String get questionnaire => 'Questionnaire';

  @override
  String get noResponses => 'Aucune réponse';

  @override
  String get deleteResponseConfirm => 'Supprimer cette réponse localement ?';

  @override
  String get pendingSync => 'En attente de synchronisation';

  @override
  String get synced => 'Synchronisée';

  @override
  String get pending => 'En attente';

  @override
  String get resend => 'Renvoyer';

  @override
  String get markedForResend => 'Réponse marquée à renvoyer';

  @override
  String responseNumber(int number) {
    return 'Réponse $number';
  }

  @override
  String get scannerTitle => 'Scanner';

  @override
  String get enterUidManuallyTooltip => 'Saisir UID manuellement';

  @override
  String get scanSurveyQr => 'Scanner un QR code de questionnaire';

  @override
  String get qrShownInDesktop =>
      'Le QR code est affiché dans l\'application Desktop';

  @override
  String get startScanner => 'Démarrer le scanner';

  @override
  String get enterUidManually => 'Saisir un UID manuellement';

  @override
  String get serverConfigured => 'Serveur configuré';

  @override
  String get serverAddressSaved =>
      'L\'adresse du serveur a été enregistrée automatiquement.';

  @override
  String get surveyDetected => 'Questionnaire détecté';

  @override
  String get importSurveyQuestion =>
      'Voulez-vous importer ce questionnaire depuis le serveur ?';

  @override
  String uidLabel(String uid) {
    return 'UID : $uid';
  }

  @override
  String get importing => 'Importation en cours...';

  @override
  String surveyImported(String name) {
    return 'Questionnaire \"$name\" importé !';
  }

  @override
  String get enter => 'Saisir';

  @override
  String importError(String error) {
    return 'Erreur lors de l\'importation : $error';
  }

  @override
  String get uidNotFound => 'UID introuvable dans le QR';

  @override
  String get qrNotRecognized => 'QR code non reconnu';

  @override
  String get enterUidTitle => 'Saisir un UID';

  @override
  String get stopScanner => 'Arrêter';

  @override
  String get pointCameraAtQr => 'Pointez la caméra sur le QR code';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get serverConnection => 'Connexion serveur';

  @override
  String get notConfigured => 'Non configuré — scannez le QR du coordinateur';

  @override
  String get testConnection => 'Tester la connexion';

  @override
  String get serverAccessible => 'Serveur accessible !';

  @override
  String get cannotReachServer => 'Impossible de joindre le serveur';

  @override
  String get configureManually => 'Configurer manuellement';

  @override
  String get coordinatorIpHelper =>
      'IP du PC coordinateur (port 8765 ajouté auto)';

  @override
  String get addressSaved => 'Adresse enregistrée';

  @override
  String get aboutTitle => 'À propos';

  @override
  String get aboutDesc => 'Lestrade Forms — Application de collecte terrain';

  @override
  String get version => 'Version 1.2.0';

  @override
  String get aboutFeatures =>
      'Collecte offline · Sync réseau local · Analyse Desktop';

  @override
  String get formTitle => 'Formulaire';

  @override
  String get surveyNotFound => 'Questionnaire introuvable';

  @override
  String get acquiringGps => 'Acquisition GPS...';

  @override
  String gpsAcquired(String accuracy) {
    return 'GPS acquis (±$accuracy m)';
  }

  @override
  String get gpsUnavailable => 'GPS indisponible';

  @override
  String get responseSavedOffline => 'Réponse enregistrée (offline)';

  @override
  String requiredFields(String fields) {
    return 'Champs requis : $fields';
  }

  @override
  String get saveResponse => 'Enregistrer la réponse';

  @override
  String get selectDate => 'Sélectionner une date';

  @override
  String get noOptionsDefined => '(aucune option définie)';

  @override
  String get emailHint => 'exemple@email.com';

  @override
  String get phoneHint => '+243...';
}
