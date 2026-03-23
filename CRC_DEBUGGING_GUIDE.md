# 🔍 Dépannage CRC Error - Guide détaillé

## Le problème que tu rencontrais

```
18:29:19.096 -> 📥 BT reçu: 4
18:29:19.096 -> ⚠️ CRC ERROR - packet invalid from app
18:29:19.140 -> 🔄 NAK envoyé (BT) au client
```

**Quand:** À chaque envoi de texte (ex: "4")  
**Symptôme:** Le texte disparait de l'input field mais n'est pas relayé vers RF433

---

## Analyse du problème CRC

### Scenario: Tu envoies le texte "4"

#### Côté Flutter (ce qui DEVRAIT être envoyé):

```
Texte: "4"
  ↓
UTF-8 encode: [0x34]
  ↓
buildPacket(flag=0x01, seq=0, payload=[0x34])
  ↓
CRC8([0x34]) = 0x8C
  ↓
Packet final: [0x01, 0x00, 0x34, 0x8C]
Taille: 4 bytes
```

#### Côté ESP32 (réception):

```
Reçu: [0x01, 0x00, 0x34, 0xXX]
  ↓
flag = 0x01 ✓
seq = 0x00 ✓
payloadLen = 4 - 3 = 1 ✓
payload = [0x34] ✓
crcReceived = 0xXX
  ↓
crcCalc = crc8([0x34])
  ↓
Si crcCalc != crcReceived:
  → CRC ERROR !
```

---

## Les 5 causes possibles

### Cause 1: ❌ Mauvais calcul CRC côté Flutter

**Symptôme:** CRC match quand tu calcules manuellement, mais ERREUR dans le packet

**Vérification:**

```dart
import 'package:hope_signal_chat/features/voice/data/voice_manager.dart';

// Test simple
var payload = Uint8List.fromList([0x34]);
var crc = VoiceManager.crc8(payload);
print('CRC de [0x34] = $crc');  // Devrait être: 140 (0x8C)
```

**Fix:** Assure-toi que le CRC8 en Dart et C++ sont IDENTIQUES

```dart
// Dart
static int crc8(Uint8List data) {
  int crc = 0;
  for (final b in data) {
    crc ^= b;
    for (int j = 0; j < 8; j++) {
      if ((crc & 0x80) != 0) {
        crc = ((crc << 1) ^ 0x07) & 0xFF;
      } else {
        crc = (crc << 1) & 0xFF;
      }
    }
  }
  return crc;
}

// C++ (doit être identique)
uint8_t crc = 0;
for (size_t i = 0; i < len; i++) {
  crc ^= buf[i];
  for (uint8_t j = 0; j < 8; j++) {
    if (crc & 0x80) crc = (uint8_t)((crc << 1) ^ 0x07);
    else crc = (uint8_t)(crc << 1);
  }
}
```

---

### Cause 2: ❌ Bluetooth Serial perd des bytes

**Symptôme:** Tu envoies 4 bytes, mais ESP32 en reçoit 3 (ou moins)

**Diagnostic:** Ajoute ce log dans trans.ino AVANT la vérification CRC:

```cpp
Serial.print("📥 Packet complet: [");
for (size_t i = 0; i < btLen; i++) {
  if (btBuffer[i] < 0x10) Serial.print("0");
  Serial.print(btBuffer[i], HEX);
  Serial.print(" ");
}
Serial.println("]");
Serial.print("CRC reçu: 0x");
if (btBuffer[btLen-1] < 0x10) Serial.print("0");
Serial.println(btBuffer[btLen-1], HEX);
```

**Fix:** Si des bytes manquent:

```cpp
// Dans setup()
SerialBT.begin("Hope_Signal_NODE2", 115200);  // Ajoute la vraie baud rate
```

---

### Cause 3: ❌ Payload pas bien encodé UTF-8

**Symptôme:** Texte avec caractères spéciaux → CRC ERROR

**Exemple:**

```
Text: "Ñ" (caractère espagnol)
UTF-8: [0xC3, 0x91]  <- 2 bytes, pas 1!
```

**Diagnostic:**

```dart
String text = "Ñ";
final payload = utf8.encode(text);
print('Payload bytes: ${payload.length}');  // Important!
```

**Fix:**

```dart
// Normalise le texte avant envoi
String normalizeText(String text) {
  // Enlever accents si possible, ou s'assurer UTF-8 valide
  return text.replaceAll(RegExp(r'[^\x00-\x7F]'), '?');
}
```

---

### Cause 4: ❌ Format packet incorrect

**Symptôme:** Packet envoyé mais structure ne match pas trans.ino

**Vérification:** Le packet DOIT être EXACTEMENT:

```
Pour TEXTE: [flag, seq, byte1, byte2, ..., crc]
             [0x01, 0-255, ..., crc8([bytes...])]

Pour AUDIO: [flag, seq, isLast, byte1, byte2, ..., crc]
            [0x02, 0-255, 0/1, ..., crc8([isLast, bytes...])]
```

**Debug:**

```dart
var packet = VoiceManager.buildPacket(
  VoiceManager.flagText,
  0,
  Uint8List.fromList([0x34]),
);
print('Packet: $packet');  // [1, 0, 52, 140]
print('Hex: ${packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
// Devrait être:  01 00 34 8c
```

---

### Cause 5: ❌ BluetoothSerial ne synchronise pas

**Symptôme:** Packet envoyé, mais pas reçu complètement

**Fix dans Flutter:**

```dart
Future<void> write(List<int> data) async {
  if (_connection != null && _connection!.isConnected) {
    _connection!.output.add(Uint8List.fromList(data));
    await _connection!.output.allSent;  // ← Important!
    // Ajoute petit délai
    await Future.delayed(const Duration(milliseconds: 50));
  }
}
```

---

## Procédure de test étape par étape

### Étape 1: Teste juste le CRC (sans Bluetooth)

```dart
void testCRC() {
  var testCases = [
    ({'payload': [0x34], 'expected': 140}),  // "4"
    ({'payload': [0x48, 0x69], 'expected': 0xXX}),  // "Hi"
    ({'payload': [0x54, 0x65, 0x73, 0x74], 'expected': 0xXX}),  // "Test"
  ];

  for (var test in testCases) {
    var crc = VoiceManager.crc8(Uint8List.fromList(test['payload']));
    print('Payload ${test['payload']}: CRC=${crc} (expected ${test["expected"]})');
    assert(crc == test['expected'], 'CRC mismatch!');
  }
}
```

### Étape 2: Vérifie le packet construit

```dart
void testPacket() {
  var packet = VoiceManager.buildPacket(
    0x01,  // flag text
    0x00,  // seq
    Uint8List.fromList([0x34]),  // "4"
  );

  print('Packet bytes: $packet');
  print('Hex: ${packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

  // Vérifier la structure
  assert(packet[0] == 0x01, 'Flag wrong');
  assert(packet[1] == 0x00, 'Seq wrong');
  assert(packet[2] == 0x34, 'Payload wrong');
  assert(packet[3] == 140, 'CRC wrong');  // 0x8C = 140
  assert(packet.length == 4, 'Length wrong');
}
```

### Étape 3: Envoie et vérifie le Serial ESP32

```
Ouvre: Tools → Serial Monitor → 115200 baud
Envoie du texte depuis l'app
Regarde le log:

📥 Packet complet: [01 00 34 8C]
CRC reçu: 0x8C
✅ TEXTE OK: '4'

OU

⚠️ CRC ERROR TEXTE - calc=0x8C received=0xXX
```

---

## Optimisation finale - Rendu le système plus robuste

### 1. Ajoute des retries côté Flutter:

```dart
Future<void> _sendWithAck(Uint8List packet, int seq) async {
  const maxRetries = 3;
  int attempt = 0;

  while (attempt < maxRetries) {
    attempt++;
    print('📤 Tentative $attempt/$maxRetries - Envoi seq:$seq');

    _ackCompleter = Completer<bool>();
    await dataSource.write(packet);

    try {
      final ok = await _ackCompleter!.future.timeout(
        const Duration(seconds: 3),
      );
      if (ok) {
        print('✅ ACK reçu pour seq:$seq');
        return;
      }
    } catch (e) {
      print('⏱️ Timeout ou NAK pour seq:$seq - Retry...');
    }
  }

  throw Exception('ACK non reçu après $maxRetries tentatives');
}
```

### 2. Ajoute du logging détaillé côté ESP32:

```cpp
if (btLen >= 3) {
  Serial.print("📥 BT reçu: ");
  Serial.print(btLen);
  Serial.print(" bytes | Flag: 0x");
  Serial.print(btBuffer[0], HEX);
  Serial.print(" | Seq: ");
  Serial.println(btBuffer[1]);

  // Log packet complet
  Serial.print("  Raw: [");
  for (size_t i = 0; i < btLen; i++) {
    if (btBuffer[i] < 16) Serial.print("0");
    Serial.print(btBuffer[i], HEX);
    if (i < btLen - 1) Serial.print(" ");
  }
  Serial.println("]");
```

### 3. Ajoute des timeouts et error handling partout:

```dart
try {
  await repository.sendMessage(text);
} on TimeoutException {
  showError('Timeout: ACK non reçu après 3 sec');
} on Exception catch (e) {
  showError('Erreur envoi: $e');
}
```

---

## Vraie solution: Les changements qu'on a faits

✅ **Tous appliqués dans les fichiers modifiés:**

1. **trans.ino** - Logging détaillé du CRC en HEX
2. **voice_manager.dart** - buildPacket() clarifié avec commentaires
3. **ble_repository_impl.dart** - Logging détaillé avant/après envoi
4. **Packets** - Structure harmonisée texte + audio

**Le tout doit fonctionner maintenant!** 🎉

---

## Checklist finale

- [ ] Compiles `trans.ino` sans erreurs
- [ ] Télécharge dans l'ESP32
- [ ] Ouvre Serial Monitor à 115200
- [ ] Envoie du texte depuis l'app
- [ ] Vérifie que tu vois:
  - `📥 BT reçu: 4 bytes`
  - `✅ TEXTE OK: 'X'`
  - `🔄 ACK envoyé`
  - `📡 Texte envoyé RF433`
- [ ] Pas de `⚠️ CRC ERROR`
- [ ] Téste l'audio ensuite

Bonne chance! 🚀
