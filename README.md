# Laboratoire d’Infrastructure Réseau

Simulation complète d’une infrastructure gouvernementale basée sur une architecture réseau à 3 couches (Core, Distribution, Access), incluant un pare-feu, un IDS, un SIEM, un SOAR léger et de l’automatisation d’incident.

### 🎯 Objectif général

Simulation de grade production d'une infrastructure réseau d'agence nationale, démontrant l'intégration entre architecture réseau, opérations de sécurité, détection de menaces et réponse automatisée.

### 📌 Phases du projet

#### Phase 1 : Architecture réseau & base de l’infra

- [x] Topologie 3-tier :Dans le cadre de notre projet de simulation, l'implémentation d'une architecture réseau hiérarchique à trois couches (Accès, Distribution, Cœur) s'impose comme un standard industriel rigoureux, principalement justifié par l'orientation dominante du trafic moderne. Nos analyses confirment que le flux majoritaire au sein de l'agence simulée est de type "East-West" (trafic latéral interne entre serveurs et applications dans le datacenter), éclipsant le trafic traditionnel "West-South" (entrant/sortant vers Internet ou les réseaux externes). Cette architecture modulaire permet de gérer ce trafic Est-Ouest de manière optimale, en utilisant la couche de Distribution pour segmenter le réseau, appliquer des contrôles de sécurité précis et optimiser le routage local, évitant ainsi l'encombrement inutile du Cœur de réseau, qui assure un transport ultra-rapide et résilient de l'ensemble des données.
![hiérarchique à trois couches]([https://raw.githubusercontent.com/yassine-ait-elasri/lab-infrastructure-reseau/refs/heads/main/images/lab-infrastructure-reseau/README/3-tiers.png])

- [ ] 
- [ ]   

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

### Phase 4 : Accès Zero-Trust (à venir)

📂 Documentation détaillée

Phase 1 — Architecture réseau

Phase 2 — SOC et automatisation
