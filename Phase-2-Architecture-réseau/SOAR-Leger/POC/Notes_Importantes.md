# 📌 Notes Importantes — Preuve de Concept (PoC)

Ce document accompagne la vidéo de démonstration du pipeline **Security Onion → Redis/Worker Python → n8n → PfSense**.
Il explique certaines **adaptations spécifiques** apportées à l’environnement afin de faciliter les tests et la démonstration.
Ces points sont importants pour comprendre pourquoi le comportement observé dans la vidéo est **différent** d’une configuration en production.

---

## ⚙️ 1. Paramètres volontairement modifiés pour la démo

### 🔹 **TTL réduit à 10 secondes**

Pour rendre les tests fluides dans la vidéo, le temps d’expiration du blocage (TTL) a été volontairement réduit à **10 secondes**.
➡️ En production, on utiliserait plutôt une durée plus longue (minutes, heures, jours).

### 🔹 **Règle Suricata : 5 requêtes / seconde**

La règle Suricata de détection brute force a été réglée sur un seuil très bas :

```
5 requêtes par seconde
```

➡️ Dans un vrai environnement, il faudrait analyser le trafic normal pour calibrer correctement le seuil.
Ici, le but est uniquement de **générer rapidement une alerte** pendant la vidéo.

---

## 🧪 2. Architecture temporaire utilisée dans la vidéo

Pour des raisons matérielles, la démonstration repose sur une configuration **simplifiée**, tout en restant réaliste.

### 🔹 **n8n sur interface pontée (bridge)**

La machine n8n utilise une interface « bridgée » reliée à mon Wi-Fi personnel.
Elle peut donc :

* accéder directement à Internet
* *cURL* le WAN de PfSense
* recevoir les alertes envoyées par le worker

### 🔹 **PfSense redirige vers la DMZ**

Une règle NAT a été configurée dans PfSense pour **rediriger les requêtes du WAN vers l’IP du nœud DMZ** contenant Security Onion / Redis.

➡️ Ceci permet à la démonstration d’être faisable avec un nombre minimal de machines.

### 🔹 **Limitation matérielle**

Je n’ai pas pu ajouter plus de machines car mon PC saturait.
L’infrastructure de la vidéo est donc volontairement compacte.

---

## 🪛 3. Scripts et worker : mode “ultra débogage”

Tous les scripts suivants fonctionnent en mode **verbeux** pour les besoins de la vidéo :

* `parse_events_to_redis.py`
* `worker_pop_and_post.py`
* les scripts shell de collecte
* les workflows n8n

Chaque étape est affichée :

* alertes poussées dans Redis
* valeurs de timestamp
* pop / push / retry
* logs HTTP envoyés vers n8n
* statut des règles sur PfSense

➡️ En production, ces logs seraient évidemment beaucoup plus silencieux.

---

## 🎯 4. Objectif du PoC

Le but de la vidéo est de montrer :

1. Détection active d’un bruteforce bas niveau
2. Capture des alertes → Redis
3. Traitement fiable avec worker Python
4. Transmission à n8n
5. Blocage automatique via PfSense
6. Déblocage automatique grâce au TTL réduit
7. Traçabilité complète via les logs affichés en direct

---

## 📎 5. Remarque finale

Cette configuration **n’est pas destinée à la production** :
elle est optimisée pour **démontrer en quelques secondes** tout le pipeline SOAR léger, avec le minimum de machines et un maximum de transparence dans les logs.

Pour un déploiement réel, il faudrait revoir :

* les TTL
* les seuils Suricata
* la gestion durable des échecs
* la haute disponibilité Redis
* et la supervision

---
