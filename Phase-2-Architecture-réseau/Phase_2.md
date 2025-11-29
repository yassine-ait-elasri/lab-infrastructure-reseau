Phase 2 — SOC & Automatisation
🎯 Objectif

Mettre en place la chaîne complète de détection et réponse automatique :

Suricata → Event.json → Redis → Worker Python → n8n → PfSense

🖥️ Machines utilisées
Machine	Rôle
Security Onion	SIEM + Suricata
Redis	Broker d’événements
Worker Python	Parse + push vers n8n
n8n	Automatisation / SOAR
PfSense	Blocage / déblocage dynamique
🛡️ Security Onion

URL : https://10.0.254.3/

Interfaces :

enp0s3 : 10.0.254.3/24

enp0s8 : none

Login : so@so.com
Pass : securityonion

🔥 Pipeline d’automatisation
1️⃣ Suricata écrit un événement

Dans :

/nsm/securityonion/logs/suricata/eve.json

2️⃣ Script Python envoie vers Redis

Le fichier est surveillé, parsé, puis push dans Redis.

3️⃣ Worker Redis → n8n Webhook

Selon le type d’alerte :

Envoi d’un POST webhook

Blocage IP via PfSense API

Unblock après X secondes

4️⃣ n8n traite le workflow

Blocage → Timer → Déblocage.

⚙️ Résultat visible

Alerte Suricata → instantanément dans Security Onion

Redis reçoit l’événement

Worker déclenche n8n

PfSense bloque automatiquement

Déblocage automatique après délai

Vidéo de démonstration enregistrée

Même si tu es débutant, on va le rendre propre, lisible, pro, et vendable pour un entretien senior.

Envoie-moi le lien dès que c’est créé.
