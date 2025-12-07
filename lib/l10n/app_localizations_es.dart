// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'MIOCard';

  @override
  String get addCard => 'Agregar tarjeta';

  @override
  String get noCardsMessage =>
      'No tienes tarjetas guardadas.\nAgrega tu primera tarjeta para comenzar.';

  @override
  String get createFirstCard => 'Crear primera tarjeta';

  @override
  String get refresh => 'Actualizar';

  @override
  String get balance => 'Saldo';

  @override
  String get balanceUnknown => 'Desconocido';

  @override
  String get lastUpdate => 'Ultima actualizacion';

  @override
  String get neverUpdated => 'Nunca actualizado';

  @override
  String get createCardTitle => 'Crear Nueva Tarjeta';

  @override
  String get back => 'Atras';

  @override
  String get cardIdLabel => 'ID de Tarjeta *';

  @override
  String get cardIdPlaceholder => 'Ingresa el ID de la tarjeta';

  @override
  String get cardPrefixLabel => 'Prefijo';

  @override
  String get cardPrefixPlaceholder => 'Prefijo opcional';

  @override
  String get cardSuffixLabel => 'Sufijo';

  @override
  String get cardSuffixPlaceholder => 'Sufijo opcional';

  @override
  String get cardNameLabel => 'Nombre *';

  @override
  String get cardNamePlaceholder => 'Nombre de la tarjeta';

  @override
  String get cardPositionLabel => 'Posicion';

  @override
  String get cardPositionPlaceholder => 'Posicion de visualizacion';

  @override
  String get createCardButton => 'Crear Tarjeta';

  @override
  String get creatingCard => 'Creando...';

  @override
  String get idRequired => 'El ID es obligatorio';

  @override
  String get nameRequired => 'El nombre es obligatorio';

  @override
  String get errorNetwork => 'Error de conexion. Verifica tu internet.';

  @override
  String get errorUnknown => 'Ha ocurrido un error desconocido';

  @override
  String get errorApi => 'Error del servidor. Intentalo mas tarde.';

  @override
  String get editCard => 'Editar tarjeta';

  @override
  String get deleteCard => 'Eliminar tarjeta';

  @override
  String get editCardTitle => 'Editar Tarjeta';

  @override
  String get saveChanges => 'Guardar Cambios';

  @override
  String get savingCard => 'Guardando...';

  @override
  String get deleteCardTitle => 'Eliminar Tarjeta';

  @override
  String deleteCardMessage(String cardName) {
    return 'Estas seguro de que quieres eliminar \"$cardName\"? Esta accion no se puede deshacer.';
  }

  @override
  String get delete => 'Eliminar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get deletingCard => 'Eliminando...';

  @override
  String get manageCards => 'Gestiona tus tarjetas de transporte';

  @override
  String get newCard => 'Nueva tarjeta';

  @override
  String get noCards => 'Sin tarjetas';

  @override
  String get settings => 'Configuracion';

  @override
  String get appearance => 'Apariencia';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeSystemDesc => 'Seguir configuracion del dispositivo';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeLightDesc => 'Tema claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get themeDarkDesc => 'Tema oscuro';

  @override
  String get fare => 'Pasaje';

  @override
  String get farePrice => 'Valor del pasaje';

  @override
  String get farePriceDesc =>
      'Se usa para calcular cuantos pasajes te alcanza el saldo';

  @override
  String get data => 'Datos';

  @override
  String get exportCards => 'Exportar tarjetas';

  @override
  String get exportCardsDesc => 'Guardar copia de seguridad';

  @override
  String get importCards => 'Importar tarjetas';

  @override
  String get importCardsDesc => 'Restaurar desde archivo';

  @override
  String get about => 'Acerca de';

  @override
  String get version => 'Version';

  @override
  String get noCardsToExport => 'No hay tarjetas para exportar';

  @override
  String get importError => 'Error al importar';

  @override
  String importedCards(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count tarjeta$_temp0 importada$_temp1';
  }

  @override
  String get noNewCardsImported => 'No se importaron tarjetas nuevas';

  @override
  String get couldNotUpdateBalance => 'No se pudo actualizar el saldo';

  @override
  String get name => 'NOMBRE';

  @override
  String fares(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    return '$count pasaje$_temp0';
  }

  @override
  String updatedAgo(String time) {
    return 'Actualizado $time';
  }

  @override
  String updatedAt(String datetime) {
    return 'Actualizado: $datetime';
  }

  @override
  String get updateBalance => 'Actualizar saldo';

  @override
  String get edit => 'Editar';

  @override
  String get cardIdExists => 'Ya existe una tarjeta con este ID';

  @override
  String get createCardError => 'Error al crear la tarjeta';

  @override
  String get saveChangesError => 'Error al guardar los cambios';

  @override
  String get farePriceUpdated => 'Valor del pasaje actualizado';

  @override
  String get balanceUpdated => 'Saldo actualizado';
}
