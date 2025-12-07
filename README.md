# MIOCard v2 - Flutter

Una aplicación Flutter moderna para gestionar tarjetas de transporte MIO.

## Características

- **Gestión de Tarjetas**: Crear, ver, editar y eliminar tarjetas de transporte
- **Consulta de Saldo**: Integración con API para obtener el saldo actual
- **Almacenamiento Local**: Persistencia usando SQLite (sqflite)
- **Soporte Multilenguaje**: Español e Inglés
- **Diseño Moderno**: Material Design 3 con gradientes y animaciones
- **Dark Mode**: Tema oscuro automático según el sistema

## Stack Tecnológico

- **Framework**: Flutter 3.x
- **State Management**: Riverpod
- **Base de Datos**: SQLite (sqflite)
- **Networking**: http package
- **Navegación**: go_router
- **Tipografías**: Google Fonts (Inter)

## Estructura del Proyecto

```
lib/
├── core/                    # Utilidades compartidas
│   ├── theme/               # Tema y estilos
│   └── utils/               # Utilidades
├── data/                    # Data Layer
│   ├── datasources/         # Fuentes de datos
│   ├── models/              # DTOs
│   └── repositories/        # Implementaciones
├── domain/                  # Domain Layer
│   ├── entities/            # Entidades
│   └── repositories/        # Interfaces
├── presentation/            # Presentation Layer
│   ├── providers/           # Riverpod providers
│   ├── screens/             # Pantallas
│   ├── widgets/             # Componentes
│   └── routes/              # Navegación
├── l10n/                    # Localización
└── main.dart                # Entry point
```

## Instalación

1. Asegúrate de tener Flutter instalado
2. Clona el repositorio
3. Ejecuta `flutter pub get`
4. Ejecuta `flutter run`

## Comandos

```bash
# Instalar dependencias
flutter pub get

# Ejecutar en modo debug
flutter run

# Compilar APK
flutter build apk

# Compilar para iOS
flutter build ios
```

## API

La aplicación se integra con:

```
GET https://www.utryt.com.co/saldo/script/saldo.php?card={cardId}
```

## Licencia

MIT License
