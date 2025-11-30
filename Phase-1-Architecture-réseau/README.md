# Phase 1 — Fondation  
**Laboratoire d’Infrastructure Réseau (NDIA)**

---

## ⭐ Résumé Exécutif

La Phase 1 constitue la fondation de l’ensemble du laboratoire réseau.  
Cette première étape met en œuvre :

- un **plan d’adressage structuré**,  
- une **segmentation claire des zones critiques**,  
- un **noyau de routage** basé sur VyOS,  
- une **périmétrie de sécurité** assurée par pfSense.

L’objectif est d’obtenir une architecture **modulaire**, **scalable**, **reproductible** et alignée avec les standards modernes (datacenter 3-tier, bonnes pratiques Enterprise/Cloud/Infra).

---

## 🧭 Architecture & Plan d’Adressage

L’infrastructure repose sur une architecture hiérarchique en **trois couches** — Accès, Distribution, Cœur — utilisée dans les environnements professionnels exigeants.

| Zone            | Sous-réseau          | Rôle |
|----------------|-----------------------|------|
| **Core Link**  | `10.0.1.0/30`         | Liaison VyOS ↔ pfSense |
| **Management** | `10.0.254.0/24`       | Supervision, administration |
| **DMZ**        | `10.0.4.0/24`         | Services exposés / semi-confiance |
| **Distribution** | `10.0.2.0/24`       | Interconnexion interne |
| **Accès**      | `10.0.3.0/24`         | Utilisateurs / terminaux |

---

## 🧩 Pourquoi une architecture 3-tier ?

L’architecture 3-tier répond aux contraintes réelles du trafic moderne.

Aujourd’hui, les environnements professionnels génèrent majoritairement du **trafic Est-Ouest** :  
applications ↔ bases de données, services internes, microservices, communications inter-VM…

L’architecture hiérarchique permet :

- **Segmentation stricte** des domaines de confiance  
- **Réduction du blast radius** en cas d’incident  
- **Optimisation du routage local** via la couche Distribution  
- **Décharge du Cœur**, qui reste dédié au transport ultra-rapide  
- **Normalisation avec les architectures institutionnelles** (NIST, ANSSI, ISO-27001)

Ce design vise la **scalabilité**, la **résilience** et l’**observabilité**, conformes aux environnements professionnels ou gouvernementaux modernes.

---

## 🖥️ Inventaire des Machines (Phase 1)

### **VyOS — Routeur Cœur**
| Interface | Adresse IP        | Rôle |
|----------|-------------------|------|
| `eth0`   | `10.0.1.1/30`     | Lien vers pfSense |
| `eth2`   | `10.0.2.1/24`    | Distribution  |

---

### **pfSense — Pare-feu Périmétrique**
| Interface | Adresse IP            | Rôle |
|----------|-----------------------|------|
| `em0`    | DHCP (`192.168.238.x`) | WAN |
| `em1`    | `10.0.1.2/30`          | Lien Core |
| `em2`    | `10.0.4.1/24`          | DMZ |
| `em3`    | `10.0.254.2/24`        | Management |

---

### **(Optionnel) VM Docker**
Permet d’héberger plusieurs routeurs/switches simulés (Distribution/Accès)  
→ réduction de consommation RAM/CPU  
→ architecture plus réaliste sans multiplier les VMs.

---

## 🔧 Prérequis Locaux

- VirtualBox (ou équivalent)
- Création des réseaux Host-Only selon le plan d’adressage
- Accès console :
  - CLI VyOS
  - GUI pfSense
- Snapshots avant modifications critiques (bonne pratique DevOps/Infra)


##  Création des réseaux Host-Only dans VirtualBox

### **Via Interface Graphique**
**VirtualBox** →  
`File` → `Host Network Manager` → `Create`  
Configurer chaque réseau selon le plan d’adressage.

<img width="1917" height="1027" alt="image" src="https://github.com/user-attachments/assets/351859d7-de30-44c4-8ea5-cae575c246e0" />

