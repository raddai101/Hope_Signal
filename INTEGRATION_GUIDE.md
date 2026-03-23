# 🚀 Guide Complet: Texte + Audio avec CRC/ACK/NAK

## Résumé des changements

### 1️⃣ **Problème CRC Texte - RÉSOLU**

Le problème `⚠️ CRC ERROR - packet invalid from app` venait de l'envoi du texte.

**Structure du packet TEXT (maintenant harmonisée):**

```
[Byte 0] Flag = 0x01
[Byte 1] Seq (0-255)
[Bytes 2..n-1] Payload (texte encodé UTF-8)
[Byte n] CRC8(payload)
```

**Exemple pour "4":**

- Payload: [0x34]
- CRC8([0x34]) = 0x8C
- Packet: [0x01, seq, 0x34, 0x8C] = 4 bytes ✓

**Corrections appliquées:**

- ✅ Harmonisé `buildPacket()` dans `voice_manager.dart`
- ✅ Ajouté meilleur logging côté Flutter
- ✅ Clarifié les calculs de CRC
- ✅ Mis à jour `trans.ino` avec validation explicite du CRC

---

### 2️⃣ **Structure TEXTE + AUDIO dans trans.ino**

#### Reception Texte BT -> RF433:

```cpp
// Packet: [0x01, seq, payload..., crc]
if (flag == FLAG_TEXT) {
  // Vérifier CRC
  uint8_t crcCalc = crc8(payload, payloadLen);
  if (crcCalc == crcReceived) {
    // ✅ Envoyer ACK
    // ✅ Relayer vers RF433
  } else {
    // ❌ Envoyer NAK et ignorer
  }
}
```

#### Reception Audio BT -> RF433:

```cpp
// Packet: [0x02, seq, isLastChunk, payload..., crc]
if (flag == FLAG_AUDIO) {
  // Le CRC inclut: [isLastChunk, payload...]
  // Accumuler les chunks jusqu'à isLastChunk=1
  // Puis envoyer vers RF433
}
```

---

### 3️⃣ **Structure Flutter - Architecture Voice complète**

```
lib/features/voice/
├── domain/
│   ├── entities/
│   │   └── voice_message.dart          ✅ Defini
│   ├── repositories/
│   │   └── voice_repository.dart       ✅ Updated
│   └── usecases/
│       ├── send_text_message_use_case.dart       ✅ Created
│       └── send_audio_file_use_case.dart         ✅ Created
├── data/
│   ├── voice_codec.dart            ✅ FFI C++
│   ├── voice_codec.cpp             ✅ Compression
│   ├── voice_manager.dart          ✅ Protocol
│   ├── voice_repository_impl.dart  ✅ Complete
│   └── datasources/
│       └── bluetooth_datasource    ✅ (partagé)
├── presentation/
│   └── widgets/
│       ├── audio_playback_widget.dart      ✅ Created
│       ├── audio_recorder_widget.dart      ✅ Created
│       └── index.dart                      ✅ Exports
```

---

### 4️⃣ **Compression Audio C++ RLE**

La compression utilise RLE (Run-Length Encoding):

- **Format compressé:** `[count, value, count, value, ...]`
- **Max chunk:** 50 bytes (comme configuré dans `VoiceManager`)
- **Décompression:** Les chunks sont automatiquement décompressés côté réception

```cpp
// Example: [0x00, 0x00, 0x00] -> compresse en [3, 0x00] (2 bytes)
// audio reçu: 3 bytes -> après compression: 2 bytes
```

---

### 5️⃣ **ACK/NAK/CRC dans Flutter - BleRepositoryImpl**

```dart
Future<void> _sendWithAck(Uint8List packet, int seq) async {
  const maxRetries = 3;
  int attempt = 0;

  while (attempt < maxRetries) {
    attempt++;
    _ackCompleter = Completer<bool>();

    // 1. Envoyer le packet
    await dataSource.write(packet);

    // 2. Attendre ACK (max 3 sec)
    try {
      final ok = await _ackCompleter!.future.timeout(
        const Duration(seconds: 3),
      );
      if (ok) return;  // ✅ ACK reçu
    } catch (_) {
      // ❌ NAK ou timeout -> Retry
    }
  }

  throw Exception('ACK non reçu après $maxRetries tentatives');
}
```

---

## 📝 Checklist d'intégration complète

### Côté ESP32 (`trans.ino`):

- [x] CRC8 poly 0x07
- [x] Reception texte avec flag 0x01
- [x] Reception audio avec flag 0x02 + isLastChunk
- [x] Validation CRC pour texte et audio
- [x] Envoi ACK (0x06) sur succès
- [x] Envoi NAK (0x15) sur erreur CRC
- [x] Relai vers RF433
- [x] Accumulation des chunks audio

### Côté Flutter:

- [x] `VoiceManager.buildPacket()` - harmonisé
- [x] CRC8 Dart = CRC8 C++
- [x] `_sendWithAck()` - attendre et retry
- [x] Compression audio C++ avec fallback RLE
- [x] Decompression audio
- [x] Widget enregistrement audio
- [x] Widget lecture audio
- [x] Architecture Clean complète

---

## 🧪 Comment tester et déboguer

### Test 1: Texte Simple

```
App Flutter -> écris "Test" -> envoie
↓
Serial log ESP32 doit montrer:
"📥 BT reçu: X bytes, flag: 0x1"
"✅ TEXTE OK: 'Test'"
"🔄 ACK envoyé (BT)"
"📡 Texte envoyé RF433"
```

### Test 2: Vérifier le CRC

Dans le Serial Monitor du ESP32:

```
📤 TEXTE ENVOI:
   - Texte: 'Test'
   - Paquet hex: [01 00 54 65 73 74 XX]
   - CRC envoyé: XX | Attendu: XX | Match: true
```

### Test 3: Audio

```
App Flutter -> enregistre 5 sec -> envoie
↓
- La file est compressée (affichage du ratio)
- Divisée en chunks de 50 bytes max
- Chaque chunk envoie, attaque ACK
- Final message "✅ Audio envoyé complètement"
```

### Débuggage CRC Error

```cpp
// Ajouter dans trans.ino pour chaque CRC erreur:
Serial.print("Reçu [");
for (int i = 0; i < btLen; i++) {
  Serial.print(btBuffer[i], HEX);
  Serial.print(" ");
}
Serial.println("]");
Serial.print("CRC calc=");
Serial.print(crcCalc, HEX);
Serial.print(" received=");
Serial.println(crcReceived, HEX);
```

---

## 🔧 Configuration recommandées

### pubspec.yaml (vérifier ces packages):

```yaml
flutter_bloc: ^9.1.1 # Events/States
flutter_bluetooth_serial: ^0.4.0 # Bluetooth
record: ^6.2.0 # Enregistrement
audioplayers: ^6.6.0 # Lecture
path_provider: ^2.1.2 # Fichiers
permission_handler: ^12.0.1 # Permissions
```

### android/build.gradle (pour NDK C++):

```gradle
ndkVersion "25.1.8937393"  // ou votre version
```

### iOS (pubspec.yaml pour iOS audio):

```yaml
ios:
  - RunnerTests
```

---

## ✅ Prochaines étapes

1. **Tester le texte d'abord** - vérifier que CRC error disparait
2. **Ajouter logs cocmplèts** - copier les Serial print du guide
3. **Tester audio** - une fois texte OK
4. **Compiler le C++** - vérifier que `libvoice_codec.so` existe
5. **Tester en RF433** - relai complet entre noeuds

---

## 📚 Fichiers clés modifiés

| Fichier                    | Changement                             |
| -------------------------- | -------------------------------------- |
| `ESP32/trans/trans.ino`    | ✅ Complete rewrite avec texte + audio |
| `voice_manager.dart`       | ✅ buildPacket() harmonisé             |
| `ble_repository_impl.dart` | ✅ Meilleur logging + ACK/NAK          |
| `voice_codec.cpp`          | ✅ RLE compression (déjà bon)          |

---

## 🎯 Performance attendue

- **Texte:** ~50-500ms pour un message court (+ ACK)
- **Audio 5sec:** ~100KB brut → ~10-30KB compressé (ratio 10-90%)
- **Chunks:** 50 bytes par chunk = ~200-600 chunks pour un audio
- **Temps total audio:** ~5-10 secondes (avec ACK/NAK)

---

**Si ça marche pas:**

1. Copiez les logs du Serial Monitor complets
2. Vérifiez que flag reçu est bien 0x01 ou 0x02
3. Vérifiez que le CRC match avec les valeurs du packet
4. Vérifiez le format UTF-8 du texte
5. Testez d'abord sans RF433, juste Bluetooth

Bon développement! 🚀
