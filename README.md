####Laboratoire d’Infrastructure Réseau

Simulation complète d’une infrastructure gouvernementale basée sur une architecture réseau à 3 couches (Core, Distribution, Access), incluant un pare-feu, un IDS, un SIEM, un SOAR léger et de l’automatisation d’incident.

🎯 Objectif général

Simulation de grade production d'une infrastructure réseau d'agence nationale, démontrant l'intégration entre architecture réseau, opérations de sécurité, détection de menaces et réponse automatisée.

📌 Phases du projet

Phase 1 : Architecture réseau & base de l’infra

Topologie 3-tier

IP addressing plan

Routage statique

PfSense + VyOS

VirtualBox organisation

Phase 2 : SOC + Automatisation

Installation Security Onion

Suricata IDS

Port mirroring

Pipeline (Suricata → Redis → Worker Python → n8n → pfSense)

Blocage/déblocage automatique

Phase 3 : Advanced Networking (à venir)

OSPF, BGP

Redondance (si possible)

Tuning réseaux

Phase 4 : Accès Zero-Trust (à venir)

📂 Documentation détaillée

Phase 1 — Architecture réseau

Phase 2 — SOC et automatisation
