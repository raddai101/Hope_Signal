# Hope Signal Chat 🛰️

**Hope Signal** est une application de communication mobile performante développée avec **Flutter**. Elle permet d'établir une liaison de chat bidirectionnelle avec des microcontrôleurs **ESP32** via le protocole Bluetooth Classic.

L'application allie une architecture logicielle robuste à une interface utilisateur moderne inspirée des standards iOS, optimisée pour la réactivité et la clarté.

---

## 🚀 Fonctionnalités Clés

* **Communication Bluetooth Classic** : Gestion complète du cycle de vie de la connexion avec l'ESP32 (Scan, Appairage, Connexion).
* **Design Moderne & Adaptatif** :
    * Support complet du **Mode Sombre** et **Mode Clair**.
    * Typographie soignée avec **Plus Jakarta Sans**.
    * Animations d'interface fluides grâce à **Lottie**.
* **Architecture BLoC** : Séparation stricte entre la logique métier et l'interface pour une maintenance facilitée.
* **Gestion Intelligente des Permissions** : Système de demande de permissions dynamique pour Android 12+ (Scan & Connect).
* **Splash Screen Natif & Flutter** : Transition invisible entre le démarrage du système et l'animation Lottie.

---

## 🛠️ Stack Technique

* **Framework** : [Flutter](https://flutter.dev)
* **Gestion d'état** : [Flutter BLoC](https://pub.dev/packages/flutter_bloc)
* **Bluetooth** : `flutter_bluetooth_serial` (Optimisé pour ESP32)
* **Animations** : [Lottie for Flutter](https://pub.dev/packages/lottie)
* **Design System** : Google Fonts & Custom iOS-like components.

---

## 📂 Structure du Projet

```text
lib/
├── core/
│   └── services/          # Logique transverse (Permissions, thèmes)
├── features/
│   └── bluetooth_chat/
│       ├── data/          # Repositories et sources de données (Bluetooth)
│       ├── presentation/
│       │   ├── bloc/      # Gestion des états (Bluetooth & Chat)
│       │   ├── pages/     # Écrans (Splash, Connexion, Chat)
│       │   └── widgets/   # Composants UI réutilisables
├── main.dart              # Point d'entrée et configuration globale
