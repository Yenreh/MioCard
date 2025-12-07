import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

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
    Locale('en'),
    Locale('es'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'MIOCard'**
  String get appName;

  /// No description provided for @addCard.
  ///
  /// In en, this message translates to:
  /// **'Add card'**
  String get addCard;

  /// No description provided for @noCardsMessage.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any saved cards.\nAdd your first card to get started.'**
  String get noCardsMessage;

  /// No description provided for @createFirstCard.
  ///
  /// In en, this message translates to:
  /// **'Create first card'**
  String get createFirstCard;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @balanceUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get balanceUnknown;

  /// No description provided for @lastUpdate.
  ///
  /// In en, this message translates to:
  /// **'Last update'**
  String get lastUpdate;

  /// No description provided for @neverUpdated.
  ///
  /// In en, this message translates to:
  /// **'Never updated'**
  String get neverUpdated;

  /// No description provided for @createCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Create New Card'**
  String get createCardTitle;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @cardIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Card ID *'**
  String get cardIdLabel;

  /// No description provided for @cardIdPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter card ID'**
  String get cardIdPlaceholder;

  /// No description provided for @cardPrefixLabel.
  ///
  /// In en, this message translates to:
  /// **'Prefix'**
  String get cardPrefixLabel;

  /// No description provided for @cardPrefixPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Optional prefix'**
  String get cardPrefixPlaceholder;

  /// No description provided for @cardSuffixLabel.
  ///
  /// In en, this message translates to:
  /// **'Suffix'**
  String get cardSuffixLabel;

  /// No description provided for @cardSuffixPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Optional suffix'**
  String get cardSuffixPlaceholder;

  /// No description provided for @cardNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get cardNameLabel;

  /// No description provided for @cardNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Card name'**
  String get cardNamePlaceholder;

  /// No description provided for @cardPositionLabel.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get cardPositionLabel;

  /// No description provided for @cardPositionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Display position'**
  String get cardPositionPlaceholder;

  /// No description provided for @createCardButton.
  ///
  /// In en, this message translates to:
  /// **'Create Card'**
  String get createCardButton;

  /// No description provided for @creatingCard.
  ///
  /// In en, this message translates to:
  /// **'Creating...'**
  String get creatingCard;

  /// No description provided for @idRequired.
  ///
  /// In en, this message translates to:
  /// **'ID is required'**
  String get idRequired;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your internet connection.'**
  String get errorNetwork;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred'**
  String get errorUnknown;

  /// No description provided for @errorApi.
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again later.'**
  String get errorApi;

  /// No description provided for @editCard.
  ///
  /// In en, this message translates to:
  /// **'Edit card'**
  String get editCard;

  /// No description provided for @deleteCard.
  ///
  /// In en, this message translates to:
  /// **'Delete card'**
  String get deleteCard;

  /// No description provided for @editCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Card'**
  String get editCardTitle;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @savingCard.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get savingCard;

  /// No description provided for @deleteCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Card'**
  String get deleteCardTitle;

  /// No description provided for @deleteCardMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{cardName}\"? This action cannot be undone.'**
  String deleteCardMessage(String cardName);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @deletingCard.
  ///
  /// In en, this message translates to:
  /// **'Deleting...'**
  String get deletingCard;

  /// No description provided for @manageCards.
  ///
  /// In en, this message translates to:
  /// **'Manage your transport cards'**
  String get manageCards;

  /// No description provided for @newCard.
  ///
  /// In en, this message translates to:
  /// **'New card'**
  String get newCard;

  /// No description provided for @noCards.
  ///
  /// In en, this message translates to:
  /// **'No cards'**
  String get noCards;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeSystemDesc.
  ///
  /// In en, this message translates to:
  /// **'Follow device settings'**
  String get themeSystemDesc;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeLightDesc.
  ///
  /// In en, this message translates to:
  /// **'Light theme'**
  String get themeLightDesc;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeDarkDesc.
  ///
  /// In en, this message translates to:
  /// **'Dark theme'**
  String get themeDarkDesc;

  /// No description provided for @fare.
  ///
  /// In en, this message translates to:
  /// **'Fare'**
  String get fare;

  /// No description provided for @farePrice.
  ///
  /// In en, this message translates to:
  /// **'Fare price'**
  String get farePrice;

  /// No description provided for @farePriceDesc.
  ///
  /// In en, this message translates to:
  /// **'Used to calculate how many fares your balance covers'**
  String get farePriceDesc;

  /// No description provided for @data.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get data;

  /// No description provided for @exportCards.
  ///
  /// In en, this message translates to:
  /// **'Export cards'**
  String get exportCards;

  /// No description provided for @exportCardsDesc.
  ///
  /// In en, this message translates to:
  /// **'Save backup copy'**
  String get exportCardsDesc;

  /// No description provided for @importCards.
  ///
  /// In en, this message translates to:
  /// **'Import cards'**
  String get importCards;

  /// No description provided for @importCardsDesc.
  ///
  /// In en, this message translates to:
  /// **'Restore from file'**
  String get importCardsDesc;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @noCardsToExport.
  ///
  /// In en, this message translates to:
  /// **'No cards to export'**
  String get noCardsToExport;

  /// No description provided for @importError.
  ///
  /// In en, this message translates to:
  /// **'Import error'**
  String get importError;

  /// No description provided for @importedCards.
  ///
  /// In en, this message translates to:
  /// **'{count} card{count, plural, =1{} other{s}} imported'**
  String importedCards(int count);

  /// No description provided for @noNewCardsImported.
  ///
  /// In en, this message translates to:
  /// **'No new cards imported'**
  String get noNewCardsImported;

  /// No description provided for @couldNotUpdateBalance.
  ///
  /// In en, this message translates to:
  /// **'Could not update balance'**
  String get couldNotUpdateBalance;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'NAME'**
  String get name;

  /// No description provided for @fares.
  ///
  /// In en, this message translates to:
  /// **'{count} fare{count, plural, =1{} other{s}}'**
  String fares(int count);

  /// No description provided for @updatedAgo.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String updatedAgo(String time);

  /// No description provided for @updatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated: {datetime}'**
  String updatedAt(String datetime);

  /// No description provided for @updateBalance.
  ///
  /// In en, this message translates to:
  /// **'Update balance'**
  String get updateBalance;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @cardIdExists.
  ///
  /// In en, this message translates to:
  /// **'A card with this ID already exists'**
  String get cardIdExists;

  /// No description provided for @createCardError.
  ///
  /// In en, this message translates to:
  /// **'Error creating card'**
  String get createCardError;

  /// No description provided for @saveChangesError.
  ///
  /// In en, this message translates to:
  /// **'Error saving changes'**
  String get saveChangesError;

  /// No description provided for @farePriceUpdated.
  ///
  /// In en, this message translates to:
  /// **'Fare price updated'**
  String get farePriceUpdated;

  /// No description provided for @balanceUpdated.
  ///
  /// In en, this message translates to:
  /// **'Balance updated'**
  String get balanceUpdated;
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
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
