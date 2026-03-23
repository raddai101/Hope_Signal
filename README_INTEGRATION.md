# 🎯 HopeSignal: Text + Audio over RF433 - Solution complète

## 📌 Problème que tu avais

```
Lors de l'envoi de texte:
⚠️ CRC ERROR - packet invalid from app
→ Le message disparaissait de l'input mais n'était jamais transmis
```

## ✅ Ce qu'on a fait

### 1. **Harmonisé le protocole CRC/ACK/NAK**

- ✅ Structure packet uniforme pour texte et audio
- ✅ CRC validation explicite côté Flutter ET ESP32
- ✅ Amélioration du logging pour debogger
- ✅ Support complet de retries avec Completer

### 2. **Implémenté la compression audio**

- ✅ RLE compression en C++
- ✅ Chunking automatique (50 bytes max)
- ✅ Accumulation et relai des chunks
- ✅ Détection du dernier chunk

### 3. **Architecture Clean complète**

- ✅ Domain: Entities, Repositories, UseCases
- ✅ Data: VoiceCodec, VoiceManager, Implementation
- ✅ Presentation: Widgets audio (playback + recorder)

---

## 🚀 Démarrage rapide (3 étapes)

### Étape 1: Upload trans.ino (5 min)

```bash
1. Ouvre: ESP32/trans/trans.ino
2. Sélectionne: Board = "ESP32 Dev Module"
3. Compile & upload
4. Ouvre Serial Monitor (115200 baud)
```

### Étape 2: Teste texte (2 min)

```bash
1. Lance l'app Flutter
2. Connecte: "Hope_Signal_NODE2"
3. Envoie: "Test"
4. Vérifie Serial: "✅ TEXTE OK: 'Test'"
```

### Étape 3: Teste audio (2 min)

```bash
1. Appuie 5 sec sur micro
2. Relâche
3. Vérifie: "✅ Audio envoyé complètement"
```

---

## 📁 Structure des fichiers modifiés

```
HopeSignal-Flutter-chat-main/
│
├── 📄 QUICKSTART.txt ⭐ COMMENCE ICI
├── 📄 MODIFICATIONS_SUMMARY.md
├── 📄 INTEGRATION_GUIDE.md (guide complet)
├── 📄 CRC_DEBUGGING_GUIDE.md (si CRC error)
├── 📄 VALIDATION_CHECKLIST.md
│
├── ESP32/
│   └── trans/
│       └── trans.ino ⭐ ENTIÈREMENT REWRITTEN
│
└── HopeSignal-Flutter-chat-main/lib/features/
    ├── bluetooth_chat/
    │   └── data/repositories/
    │       └── ble_repository_impl.dart ✅ Meilleur logging
    │
    └── voice/
        ├── domain/
        │   ├── repositories/voice_repository.dart ✅ Mis à jour
        │   └── usecases/ ✅ Created (2 fichiers)
        ├── data/
        │   ├── voice_manager.dart ✅ Harmonisé
        │   ├── voice_codec.cpp ✅ RLE compression
        │   └── voice_repository_impl.dart ✅ Complet
        └── presentation/
            └── widgets/ ✅ Audio playback + recorder
```

---

## 🔧 Points clés du fix

### 1. CRC Calculation (Identique Dart ↔️ C++)

```cpp
// C++ ESP32
uint8_t crc8(const uint8_t *buf, size_t len) {
  uint8_t crc = 0;
  for (size_t i = 0; i < len; i++) {
    crc ^= buf[i];
    for (uint8_t j = 0; j < 8; j++) {
      if (crc & 0x80) crc = (uint8_t)((crc << 1) ^ 0x07);
      else crc = (uint8_t)(crc << 1);
    }
  }
  return crc;
}

// Dart Flutter
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
```

### 2. Packet Structure (TEXT)

```
[0x01][Seq][Payload bytes...][CRC8(payload)]
 Flag  0-255  UTF-8 string       1 byte

Exemple: "Hi" →
[0x01][0x00][0x48][0x69][CRC]
```

### 3. Packet Structure (AUDIO)

```
[0x02][Seq][LastChunk][Payload bytes...][CRC8([LastChunk, Payload])]
 Flag  0-255    0/1       50 bytes max      1 byte

LastChunk = 1 si c'est le dernier chunk, 0 sinon
```

### 4. ACK/NAK Protocol

```
ESP32 → Flutter:
- ACK: [0x06][Seq]  ← Packet reçu et validé
- NAK: [0x15][Seq]  ← CRC error ou problème

Flutter: Attend ACK max 3 secondes
Si NAK ou timeout: Retry 3 fois
```

---

## 🧪 Tests recommandés dans cet ordre

1. **Texte court ("Hi")** ← Start here
2. **Texte long ("Lorem ipsum...")**
3. **Texte spéciaux (123!@#)**
4. **Audio 3-5 sec**
5. **RF433 relai (si matériel dispo)**

Pour chaque test, vérifie les logs ESP32:

```
✅ "✅ TEXTE OK:" ou "✅ AUDIO CHUNK OK" → Succès!
❌ "⚠️ CRC ERROR" → Debug (voir guide)
```

---

## ⚠️ Si tu rencontres CRC ERROR

**STOP ET LIRE: `CRC_DEBUGGING_GUIDE.md`**

Causes possibles:

1. Bluetooth perte données
2. Encoding UTF-8 problème
3. CRC calculation différente
4. Bluetooth Classic baud rate
5. Timing issue

---

## 📊 Architecture Vue d'ensemble

```
┌─────────────────────────────────────────────┐
│           FLUTTER APP (Texte + Audio)        │
├─────────────────────────────────────────────┤
│  ChatPage with AudioRecorder + AudioPlayer  │
│  (voice/presentation/widgets)               │
├─────────────────────────────────────────────┤
│  ChatBloc / SendEvent (existing)            │
│  VoiceRepository (new)                      │
├─────────────────────────────────────────────┤
│  BleRepositoryImpl (updated)                 │
│  - buildPacket (TEXT + AUDIO)               │
│  - _sendWithAck (retries)                   │
│  - _handleIncoming (ACK/NAK/CRC)            │
├─────────────────────────────────────────────┤
│  BluetoothClassicDataSource                 │
│  (Bluetooth Serial HC-05/HC-06)             │
└─────────────────────────────────────────────┘
              ↕ Bluetooth Serial
┌─────────────────────────────────────────────┐
│         ESP32 (trans.ino)                    │
├─────────────────────────────────────────────┤
│  BluetoothSerial Receive Loop:              │
│  ├─ FLAG 0x01: TEXT + CRC validation       │
│  │  └─ ACK/NAK + RF433 relay               │
│  ├─ FLAG 0x02: AUDIO + CRC validation      │
│  │  ├─ Accumulate chunks                  │
│  │  └─ Relay when complete                │
│  └─ RF433 data relay                       │
├─────────────────────────────────────────────┤
│  VoiceCodec.cpp (RLE Compression)          │
└─────────────────────────────────────────────┘
              ↕ RF433 (RadioHead)
┌─────────────────────────────────────────────┐
│    Autre ESP32 or Station                   │
│    (Same trans.ino)                         │
└─────────────────────────────────────────────┘
```

---

## 📖 Documentation incluuse

| Document                   | Objectif                        |
| -------------------------- | ------------------------------- |
| `QUICKSTART.txt`           | 3 étapes rapides                |
| `MODIFICATIONS_SUMMARY.md` | Ce qui a changé                 |
| `INTEGRATION_GUIDE.md`     | Explication complète (25 pages) |
| `CRC_DEBUGGING_GUIDE.md`   | Debug le CRC error (25 pages)   |
| `VALIDATION_CHECKLIST.md`  | Tester les fonctionnalités      |
| Ce README                  | Vue d'ensemble                  |

---

## 🎯 Checklist finale avant mise en prod

- [ ] Texte simple fonctionne (CRC OK)
- [ ] Audio enregistrement fonctionne
- [ ] Audio playback fonctionne
- [ ] Pas de CRC ERROR dans les logs
- [ ] ACK reçu 100% du temps (normal ops)
- [ ] RF433 relai fonctionne (si dispo)
- [ ] Compression ratio 10-40%
- [ ] Délai < 1 second pour texte

---

## 🚀 Commande rapide pour toi

```bash
# 1. Flutter
flutter pub get  # Assuré que tous les packages sont OK

# 2. Android NDK C++ compilation (pour audio compression)
# gradle build ou Android Studio compile automatiquement

# 3. ESP32
# Arduino IDE: ESP32/trans/trans.ino → Upload

# 4. Test
flutter run
```

---

## 💬 Notes

**Version:** 1.0 (Fix CRC + Architecture Audio)  
**Date:** 2026-03-23  
**Status:** ✅ Ready for testing

**Prochaines améliorations possibles:**

- Encryption pour Bluetooth
- Resume interrupted audio transfers
- Bigger chunks (50→100 bytes) après tests
- Statistics dashboard

---

## ✨ Bon développement!

Des questions? Consulte les guides detaillés incluus.  
Des problèmes? Commence par `CRC_DEBUGGING_GUIDE.md`.  
Prêt à tester? Commence par `QUICKSTART.txt`.

🚀 **GO!**
