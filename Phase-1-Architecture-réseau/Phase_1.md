Phase 1 — Architecture Réseau
🏷 Nom du laboratoire

Laboratoire d’Infrastructure Réseau

🎯 Objectif

Mettre en place la couche réseau fondamentale :

Topologie 3-tier (Core / Distribution / Access)

PfSense + VyOS

Adressage IP

Routage de base

Isolation des zones (DMZ / Management / LAN)

🖥️ Machines de la Phase 1
Machine	Rôle
PfSense	Firewall + segmentation des zones
VyOS	Routeur Core
VirtualBox Adapters	Représentation logique des réseaux
🌐 Plan d’adressage
🔸 VirtualBox Host-Only Networks
10.0.1.0/24    Core layer
10.0.2.0/24    Distribution layer
10.0.3.0/24    Access layer
10.0.4.0/24    DMZ layer
10.0.254.0/24  Management layer
10.0.10.0/24   LAN interne

🔥 PfSense

URL : https://10.0.254.2/

IP Interfaces :

em0 : DHCP (192.168.238.121)

em1 : 10.0.1.2/30

em2 : 10.0.4.1/24

em3 : 10.0.254.0/24

Login : admin
Pass : admin
API KEY : 57a0f7b0e3f2fb9cf9f99d2d49ba9440

🚦 VyOS
eth0 10.0.1.1/30
eth1 10.0.254.1/24
eth2 10.0.10.1/24

🔎 Résultats attendus

Ping fonctionnel entre core-distribution-access

Management et DMZ isolés

Tout trafic doit passer par PfSense

Base du routage établie

Maintenant crée le fichier phase2.md

Même procédure :
Add file → Create new file → docs/phase2.md

Colle :

Phase 2 — SOC & Automatisation
🎯 Objectif

Mettre en place la chaîne complète de détection et r
