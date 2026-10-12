# Publicar la app de iPhone (Ottos) desde un Mac

Guía paso a paso para compilar la app y subirla a TestFlight desde tu Mac, para 2 personas de prueba.
La app ya está preparada: nombre «Ottos», identificador `com.remesadeotto.ottos`, icono, permisos de Face ID y de
notificaciones, y apunta a producción (`https://api.remesadeotto.com`).

## 1. En la web de Apple (una sola vez)

**a. Registrar el identificador** — https://developer.apple.com/account › Certificates, IDs & Profiles › Identifiers › **+**

- App IDs › App › Continue.
- Description: `Ottos`. Bundle ID: **Explicit**, `com.remesadeotto.ottos`.
- No marques ninguna capacidad extra. Continue › Register.

**b. Crear la app** — https://appstoreconnect.apple.com › Apps › **+** › New App

- Platforms: iOS. Name: `Ottos` (si está cogido, por ejemplo `Ottos Remesas`; en el iPhone se seguirá viendo «Ottos»).
- Primary language: Spanish. Bundle ID: `com.remesadeotto.ottos`. SKU: `ottos`. Create.

## 2. Preparar el Mac (una sola vez)

1. **Xcode** desde la App Store. Ábrelo una vez y acepta lo que pida (licencia, componentes).
2. En Xcode › Settings › Accounts › **+** › Apple ID: entra con tu cuenta de Apple Developer.
3. En el Terminal:

   ```sh
   # Homebrew, si no lo tienes: https://brew.sh
   brew install cocoapods

   # Flutter, la misma versión del proyecto
   git clone https://github.com/flutter/flutter.git -b 3.47.7 ~/flutter
   echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   flutter doctor        # debe salir Xcode y CocoaPods en verde
   ```

## 3. Descargar el proyecto

```sh
git clone https://github.com/jjhurtado/ottos-frontend.git
cd ottos-frontend
git checkout 1.0.0-rc.2
flutter pub get
```

## 4. Elegir tu equipo para firmar (una sola vez)

```sh
cd apps/ottos_courier
open ios/Runner.xcworkspace
```

En Xcode: a la izquierda haz clic en **Runner** (el icono azul) › pestaña **Signing & Capabilities** › en **Team** elige
tu equipo. Deja marcado «Automatically manage signing». El Bundle Identifier debe decir `com.remesadeotto.ottos`.
Cierra Xcode.

## 5. Compilar

Desde `apps/ottos_courier`:

```sh
flutter build ipa --release --dart-define=OTTOS_API_URL=https://api.remesadeotto.com
```

Tarda unos minutos. Al final deja el archivo en `build/ios/ipa/` (termina en `.ipa`).

> Importante: compila siempre con ese `--dart-define`. Sin él, la app intentaría conectarse a este ordenador en vez de a
> producción y no podría entrar.

## 6. Subir a TestFlight

1. Instala **Transporter** desde la App Store del Mac (es de Apple y gratis) y entra con tu Apple ID.
2. Arrastra el `.ipa` de `build/ios/ipa/` a Transporter › **Deliver**.
3. En App Store Connect › tu app › **TestFlight**, en 10–30 minutos aparece la versión. Si pregunta por cifrado
   («Export Compliance»), la app ya lo declara: solo usa el cifrado estándar de HTTPS.

## 7. Invitar a las 2 personas

En App Store Connect › tu app › TestFlight:

- **Si son de tu equipo** (Users and Access): grupo interno, se añaden y reciben el correo al momento.
- **Si no lo son**: **External Testing › +**, crea un grupo, añade sus correos y la versión. Apple revisa la primera
  versión de prueba (suele tardar alrededor de un día). Te pedirá un correo de contacto y una frase de qué probar.

Ellas instalan la app **TestFlight** en su iPhone y abren el enlace del correo.

## Siguientes versiones

Cada subida necesita un número de compilación mayor que el anterior. Para la siguiente:

```sh
flutter build ipa --release --build-number=4 --dart-define=OTTOS_API_URL=https://api.remesadeotto.com
```

(y luego 5, 6…). La versión visible (1.0.0-rc.2) la cambia la próxima release del proyecto.

## Si algo falla

- **«No signing certificate» o «No profiles»**: repite el paso 4; comprueba en Xcode › Settings › Accounts que tu
  cuenta aparece con tu equipo.
- **Errores de CocoaPods**: en `apps/ottos_courier/ios` ejecuta `pod repo update` y vuelve a compilar.
- **El nombre ya existe en App Store Connect**: usa otro en el paso 1b; el del iPhone no cambia.

La alternativa sin Mac (compilar en GitHub) está en `.github/workflows/ios-testflight.yml`.
