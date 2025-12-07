// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'MIOCard';

  @override
  String get addCard => 'Add card';

  @override
  String get noCardsMessage =>
      'You don\'t have any saved cards.\nAdd your first card to get started.';

  @override
  String get createFirstCard => 'Create first card';

  @override
  String get refresh => 'Refresh';

  @override
  String get balance => 'Balance';

  @override
  String get balanceUnknown => 'Unknown';

  @override
  String get lastUpdate => 'Last update';

  @override
  String get neverUpdated => 'Never updated';

  @override
  String get createCardTitle => 'Create New Card';

  @override
  String get back => 'Back';

  @override
  String get cardIdLabel => 'Card ID *';

  @override
  String get cardIdPlaceholder => 'Enter card ID';

  @override
  String get cardPrefixLabel => 'Prefix';

  @override
  String get cardPrefixPlaceholder => 'Optional prefix';

  @override
  String get cardSuffixLabel => 'Suffix';

  @override
  String get cardSuffixPlaceholder => 'Optional suffix';

  @override
  String get cardNameLabel => 'Name *';

  @override
  String get cardNamePlaceholder => 'Card name';

  @override
  String get cardPositionLabel => 'Position';

  @override
  String get cardPositionPlaceholder => 'Display position';

  @override
  String get createCardButton => 'Create Card';

  @override
  String get creatingCard => 'Creating...';

  @override
  String get idRequired => 'ID is required';

  @override
  String get nameRequired => 'Name is required';

  @override
  String get errorNetwork => 'Network error. Check your internet connection.';

  @override
  String get errorUnknown => 'An unknown error occurred';

  @override
  String get errorApi => 'Server error. Please try again later.';

  @override
  String get editCard => 'Edit card';

  @override
  String get deleteCard => 'Delete card';

  @override
  String get editCardTitle => 'Edit Card';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get savingCard => 'Saving...';

  @override
  String get deleteCardTitle => 'Delete Card';

  @override
  String deleteCardMessage(String cardName) {
    return 'Are you sure you want to delete \"$cardName\"? This action cannot be undone.';
  }

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get deletingCard => 'Deleting...';

  @override
  String get manageCards => 'Manage your transport cards';

  @override
  String get newCard => 'New card';

  @override
  String get noCards => 'No cards';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeSystemDesc => 'Follow device settings';

  @override
  String get themeLight => 'Light';

  @override
  String get themeLightDesc => 'Light theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeDarkDesc => 'Dark theme';

  @override
  String get fare => 'Fare';

  @override
  String get farePrice => 'Fare price';

  @override
  String get farePriceDesc =>
      'Used to calculate how many fares your balance covers';

  @override
  String get data => 'Data';

  @override
  String get exportCards => 'Export cards';

  @override
  String get exportCardsDesc => 'Save backup copy';

  @override
  String get importCards => 'Import cards';

  @override
  String get importCardsDesc => 'Restore from file';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get noCardsToExport => 'No cards to export';

  @override
  String get importError => 'Import error';

  @override
  String importedCards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count card$_temp0 imported';
  }

  @override
  String get noNewCardsImported => 'No new cards imported';

  @override
  String get couldNotUpdateBalance => 'Could not update balance';

  @override
  String get name => 'NAME';

  @override
  String fares(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count fare$_temp0';
  }

  @override
  String updatedAgo(String time) {
    return 'Updated $time';
  }

  @override
  String updatedAt(String datetime) {
    return 'Updated: $datetime';
  }

  @override
  String get updateBalance => 'Update balance';

  @override
  String get edit => 'Edit';

  @override
  String get cardIdExists => 'A card with this ID already exists';

  @override
  String get createCardError => 'Error creating card';

  @override
  String get saveChangesError => 'Error saving changes';

  @override
  String get farePriceUpdated => 'Fare price updated';

  @override
  String get balanceUpdated => 'Balance updated';
}
