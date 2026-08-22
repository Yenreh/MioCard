# Inspecting the official MIO app

Steps to recover the balance endpoint used by the official app, in case
Metrocali changes it and MIOCard stops working.

Findings as of 2026-08-22 (official app version 5.3.3, versionCode 50).

## 1. Locate and pull the APK

```bash
ADB=~/Android/Sdk/platform-tools/adb
$ADB shell pm list packages | grep -i mio
# -> co.gov.metrocalitransporte.mio_app
$ADB shell pm path co.gov.metrocalitransporte.mio_app
$ADB pull <base.apk path> /tmp/mio/base.apk
```

Split APKs (`split_config.*`) hold native libs and resources only; the JS
lives in `base.apk`.

## 2. Extract the JavaScript bundle

The app is React Native / Expo, so the logic is in a Hermes bytecode bundle.

```bash
cd /tmp/mio && unzip -o -q base.apk -d extracted 'assets/*' 'classes*.dex'
file extracted/assets/index.android.bundle   # Hermes JavaScript bytecode
cat extracted/assets/app.config              # version, expo project id
```

Check whether an over-the-air update replaced the bundle. `app.config`
carries `updates.url` and `runtimeVersion`:

```bash
curl -sS 'https://u.expo.dev/<projectId>' \
  -H 'expo-platform: android' \
  -H 'expo-runtime-version: 5.3.3' \
  -H 'expo-channel-name: production' \
  -H 'expo-protocol-version: 1' \
  -H 'accept: multipart/mixed,application/expo+json,application/json'
```

As of this writing no channel serves updates, so the APK bundle is what
runs on the device.

## 3. Mine URLs out of the bundle

String literals survive in Hermes bytecode, but they are stored back to
back with no separators, so every match carries garbage on both ends.
List hosts first, then pull the full URLs:

```bash
cd extracted/assets
grep -aoE '://[a-zA-Z0-9._-]+\.[a-z]{2,6}' index.android.bundle |
  sed 's|://||' | sort -u

python3 - <<'PY'
import re
data = open('index.android.bundle','rb').read()
for m in re.finditer(rb'https?://[\x21-\x7e]{4,120}', data):
    u = m.group().decode('latin1')
    if any(k in u for k in ('metrocali','siur','utryt')):
        print(u[:160])
PY
```

Note `ugrep` (aliased to grep on this machine) rejects patterns with large
bounded repetitions; use the Python snippet for context dumps.

## 4. Endpoints found

| Purpose | URL |
| --- | --- |
| Card balance | `https://metrocali.gov.co/cts/api/cts.php?numero={13 digits}` |
| Card exists | `https://apps.metrocali.gov.co/proxy/cards/api/v1/cards/exists/` |
| User by document | `https://apps.metrocali.gov.co/proxy/cards/api/v1/users/document/` |
| Stops by line | `https://wsmio.siur.com.co:8083/apiMIO/jaxrs/linestops/` |
| Buses near a stop | `https://servicios.siur.com.co/buscarutas/api/paradas_con_buses_proximos_a_llegar.php?latitud=` |
| PQRSD | `https://www.metrocali.gov.co/pqrsf/api/MOV_prepare.php` |

## 4b. The jaxrs API describes itself

`wsmio.siur.com.co:8083` runs Jersey and serves its own WADL, which lists
every resource without any guessing:

```bash
curl -sS 'https://wsmio.siur.com.co:8083/apiMIO/jaxrs/application.wadl?detail=true'
```

Resources that answered with data:

| Resource | Returns |
| --- | --- |
| `balance/{card}` | `{cardNumber, balance, pendingBalance}` |
| `balance2/{card}` | the same payload `cts.php` proxies |
| `stations` | every station with id, name, address, lat/lon |
| `lines` | every line with id and short name |
| `linesByStop/{stop}` | lines serving a stop |
| `linesOperation` | first and last service time per line |
| `pevrs/{lat}/{lon}/{rad}` | recharge points near a position |

`stops/{lat}/{lon}/{rad}`, `linestops/{line}`, `operations/{line}` and
`busInfo/{bus}` answered `[]` for every argument tried.

## 4c. Arrivals contract

```
GET https://servicios.siur.com.co/buscarutas/api/paradas_con_buses_proximos_a_llegar.php
    ?latitud={lat}&longitud={lon}&radio={metres}
```

`radio` is required and must be 300 or less. The response is an array of
stops, each with the buses on their way:

```json
[{"idParada":"500800","nombreParada":"Plaza de Cayzedo A1",
  "distanciaMetros":119.52,
  "buses":[{"nombreLinea":"E21","nombreDestino":"Est. Universidades",
            "tiempoEstimadoDeSalida":1787429222000,"vehiculoId":"637001"}]}]
```

`tiempoEstimadoDeSalida` is epoch milliseconds. Errors come back as
`{"error": "..."}` with HTTP 200.

The service only accepts coordinates, never a stop id, and it does not
return the coordinates of the stops it finds. MIOCard therefore stores,
for every favorite, the position it was found from and queries a small
radius around that anchor.

## 5. Balance endpoint contract

Success (HTTP 200):

```json
{"cardNumber":1906051868981,"cd_id":6,"crd_snr":5186898,
 "tsn":525,"balance":15300.0,"balanceDate":1785631011000}
```

`balanceDate` is epoch milliseconds.

Failures also return HTTP 200:

```json
{"error":"No se recibió el número de tarjeta"}
{"error":"Error al consultar la API externa"}
```

The proxy collapses every upstream problem into that generic message, so
MIOCard falls back to the utryt endpoint to tell an invalid card apart
from a backend failure.

## 6. utryt fallback contract

`GET https://www.utryt.com.co/saldo/script/saldo.php?card={13 digits}`

Apache/PHP 5.4 in front of Oracle ORDS. Always HTTP 200. Business errors
arrive as an ORDS payload whose `cause` carries the Oracle code:

- `ORA-20001` - card number must have exactly 13 digits
- `ORA-20002` - no movements found for the card
- `ORA-20003` wrapping `ORA-20010` - query limit exceeded for this origin
  (per public IP; mobile carriers behind CGNAT share and exhaust it)

## 7. If the balance stops working

1. Re-run steps 1-3 against the current APK and diff the host list.
2. Verify each candidate URL with curl and a known-good card number.
3. Update `lib/data/datasources/card_remote_datasource.dart` and the
   fixtures in `test/card_remote_datasource_test.dart`.

Runtime capture (PCAPdroid, or mitmproxy plus a proxy on the phone) is a
last resort: it needs TLS interception and the app may pin certificates.
Static string mining answered every question so far.
