<div align="center">

  <img src="lib/imagenes/logoPharmaSalud.png" alt="PharmaSalud Logo" width="120" height="120" />

  # PharmaSalud 💊

  **Sistema Integral de Gestión Farmacéutica, Punto de Venta (POS) y Control de Inventarios**

  [![Flutter](https://img.shields.io/badge/Flutter-3.5%2B-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.5%2B-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
  [![Platform](https://img.shields.io/badge/Platform-Windows%20Desktop-0078D6?style=for-the-badge&logo=windows&logoColor=white)](https://flutter.dev/desktop)
  [![Database](https://img.shields.io/badge/Database-SQLite%20FFI-003B57?style=for-the-badge&logo=sqlite&logoColor=white)](https://pub.dev/packages/sqflite_common_ffi)
  [![Version](https://img.shields.io/badge/Version-3.0.6-success?style=for-the-badge)](#)

</div>

---

## 📋 Descripción General

**PharmaSalud** es una solución de escritorio robusta y moderna desarrollada en **Flutter** para optimizar la operativa diaria en farmacias y boticas. Ofrece una experiencia fluida, rápida y confiable que integra punto de venta (POS), control de stock por lote y caducidad, kardex automatizado, cuadres de caja y analítica visual de ventas en tiempo real.

Diseñado específicamente para operar de manera local con alta velocidad de respuesta mediante **SQLite FFI**, permitiendo a administradores y vendedores gestionar transacciones sin depender de una conexión a internet ininterrumpida.

---

## ✨ Características Principales

### 🛒 1. Punto de Venta Ágil (POS)
* **Búsqueda instantánea:** Filtrado en tiempo real de medicamentos por nombre, código de barras o principio activo.
* **Carrito interactivo:** Soporte para venta fraccionada, cálculo dinámico de totales, descuentos e impuestos.
* **Impresión térmica (ESC/POS):** Emisión nativa de tickets de venta en impresoras térmicas (58mm / 80mm) con soporte para comandos ESC/POS y compatibilidad Win32.
* **Control de caja:** Registro de apertura, corte de turno, sobrantes/faltantes y cuadre global.

### 📦 2. Control de Inventario & Kardex
* **Gestión de catálogo:** Alta, edición y categorización de medicamentos y productos de salud.
* **Kardex automatizado:** Trazabilidad estricta de entradas, salidas, mermas y ajustes manuales.
* **Alertas preventivas:** Notificaciones automáticas de productos con stock crítico y fechas próximas de vencimiento.
* **Conteos de inventario:** Herramienta para campañas de inventario físico y conciliación de discrepancias.

### 📊 3. Panel de Analítica y Reportes
* **Dashboard interactivo:** Visualización gráfica con `fl_chart` de tendencias semanales y mensuales.
* **Métricas de rendimiento:** Ranking de productos más vendidos y desempeño por vendedor.
* **Exportación & Importación:** Compatibilidad para importar y exportar catálogos y reportes en formato **CSV**.

### 🔐 4. Seguridad y Gestión de Roles
* **Acceso por perfiles:** Permisos diferenciados entre **Administrador** (gestión total, finanzas, usuarios) y **Vendedor** (POS, consultas operativas).
* **Modo privado:** Protección visual de montos y totales en pantalla ante la presencia de clientes.
* **Persistencia segura:** Almacenamiento local aislado mediante `shared_preferences` y base de datos relacional.

---

## 🏗️ Arquitectura del Proyecto

El proyecto sigue una arquitectura desacoplada y orientada al patrón **Repository**, separando la interfaz de usuario de las reglas de negocio y el acceso a datos.

```text
pharma_salud/
├── assets/                     # Fuentes tipográficas, iconos y configuraciones
│   ├── fonts/                  # Tipografía Outfit y fuentes personalizadas
│   └── icon/                   # Icono oficial de la aplicación
├── installers/                 # Scripts de empaquetado Inno Setup (.iss)
├── lib/
│   ├── components/             # Componentes transversales (Layout principal, barras de título)
│   ├── database/               # Conexión SQLite FFI y migraciones de esquemas
│   ├── graficos/               # Widgets y controladores de visualización de datos
│   ├── imagenes/               # Recursos gráficos embebidos de la aplicación
│   ├── repositories/           # Capa de acceso a datos (Kardex, Productos, Ventas, Usuarios)
│   ├── screens/                # Vistas de la aplicación
│   │   ├── Admin/              # Módulos administrativos (Dashboard, Inventario, Reportes)
│   │   ├── Login/              # Pantalla de autenticación y bienvenida
│   │   └── Vendedor/           # Interfaz de Punto de Venta y operaciones de caja
│   ├── services/               # Lógica de negocio (impresión raw, exportaciones CSV)
│   ├── utils/                  # Formateadores de moneda/fechas, diálogos y helpers
│   ├── widgets/                # Widgets reutilizables de UI (botones, inputs, tablas)
│   └── main.dart               # Punto de entrada, configuración de ventana y arranque
└── test/                       # Pruebas unitarias y de widgets
```

---

## 🛠️ Tecnologías y Librerías

| Componente | Tecnología | Propósito |
|---|---|---|
| **Framework** | Flutter (Desktop Windows) | Interfaz gráfica fluida y multiplataforma |
| **Lenguaje** | Dart 3.5+ | Lógica de negocio con tipado estricto |
| **Persistencia** | SQLite (`sqflite_common_ffi`) | Motor de base de datos relacional local ultrarrápido |
| **Manejo de Estado** | Provider / Stateful Architecture | Gestión reactiva de estados en interfaz |
| **Gráficos** | `fl_chart` | Visualización de métricas y estadísticas financieras |
| **Impresión** | `esc_pos_utils_plus` / Win32 FFI | Generación y envío de comandos a impresoras de tickets |
| **Ventanas nativas** | `bitsdojo_window` | Personalización del marco de ventana en Windows |
| **Empaquetador** | Inno Setup | Generación del instalador ejecutable (`.exe`) |

---

## 🚀 Instalación y Puesta en Marcha

### Requisitos Previos
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (versión 3.5 o superior)
* [Visual Studio 2022](https://visualstudio.microsoft.com/) con la carga de trabajo *"Desarrollo para el escritorio con C++"*
* [Git](https://git-scm.com/)

### 1. Clonar el repositorio
```bash
git clone https://github.com/Sciclox/PharmaSalud.git
cd PharmaSalud
```

### 2. Instalar dependencias
```bash
flutter pub get
```

### 3. Ejecutar en modo desarrollo
```bash
flutter run -d windows
```

### 4. Ejecutar pruebas unitarias
```bash
flutter test
```

---

## 📦 Generación del Instalador de Producción

1. **Compilar la versión Release para Windows:**
   ```bash
   flutter build windows --release
   ```
2. **Generar el instalador con Inno Setup:**
   * Abrir el archivo `installers/installer.iss` con Inno Setup Compiler.
   * Compilar el script para generar el instalador final en `installers/installer/PharmaSalud_Setup.exe`.

---

## 👨‍💻 Contribuciones y Estándares de Código

* Los commits siguen la convención de [Conventional Commits](https://www.conventionalcommits.org/):
  * `feat:` para nuevas características.
  * `fix:` para corrección de bugs.
  * `docs:` para documentación.
  * `chore:` para mantenimiento y configuración de build.
* Antes de enviar un cambio, verificar que las pruebas pasen con `flutter test` y el análisis de código con `flutter analyze`.

---

## 📄 Licencia

Este proyecto está bajo la Licencia Propietaria de uso interno para **PharmaSalud**. Todos los derechos reservados.
