# Settings Screen - Design Document

> **Pour Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implémenter l'écran Settings avec gestion des clés SSH, connexions rapides, thèmes et sécurité.

**Architecture:** Écran Settings avec 4 sections scrollables, utilisant Riverpod pour l'état et flutter_secure_storage pour les clés SSH.

**Tech Stack:** Flutter, Riverpod, flutter_secure_storage, local_auth, file_picker

---

## Section 1 : Structure générale

L'écran Settings divisé en 4 sections :
1. **Clés SSH** - Liste + ajout (import/génération)
2. **Connexions rapides** - Toggles on/off pour sessions
3. **Apparence** - Sélecteur de thème (Warp Dark, Dracula, Nord)
4. **Sécurité** - Biométrique + auto-lock

Navigation : Header identique au terminal, bouton Settings actif.

---

## Section 2 : Clés SSH

**Liste des clés :**
- Affiche nom, type (Ed25519/RSA), date d'ajout
- Tap → Détails + clé publique à copier
- Swipe gauche → Supprimer avec confirmation

**Ajout (Bottom sheet) :**
1. Importer une clé → File picker (.pem/.pub)
2. Générer une clé → Formulaire (nom, type Ed25519/RSA)

**Stockage :**
- Clé privée → flutter_secure_storage (chiffrée)
- Métadonnées → stockage local simple

---

## Section 3 : Connexions rapides

- Liste des sessions sauvegardées avec toggle ON/OFF
- Toggle ON = visible dans tab bar terminal
- Toggle OFF = cachée (pas supprimée)
- Tap → Éditer (host, port, user, clé SSH associée)

---

## Section 4 : Apparence + Sécurité

**Apparence :**
- 3 miniatures thèmes côte à côte
- Tap = sélection immédiate
- Warp Dark par défaut

**Sécurité :**
- Toggle déverrouillage biométrique
- Toggle verrouillage auto (5 min)
