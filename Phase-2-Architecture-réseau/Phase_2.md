

# 📘 README.md — Phase 2 : Architecture de Supervision & SOAR Léger


# Phase 2 — Supervision Réseau & SOAR Léger  
Pipeline : Suricata (Security Onion) → Redis → Workers → n8n → pfSense

## 📌 Objectif de la Phase 2
Cette phase met en place une architecture opérationnelle complète permettant :

- La collecte d’événements réseau via **Suricata** (Security Onion).  
- Le suivi automatique des fichiers d’événements horodatés (rotation, offsets, .gz).  
- L’expédition des nouvelles alertes dans un **buffer Redis**.  
- La consommation de ces alertes par un ou plusieurs **workers Python**.  
- L’appel de **workflows n8n** déclenchant des actions réseau (ex : blocage IP).  
- La mise à jour dynamique d’un alias **autoblock** sur **pfSense**.  
- Le déblocage automatique après expiration (scheduler).

Le tout en **open source**, sans dépendre des connecteurs payants d’Elastic/Kibana.

---

# 📁 Arborescence du dossier


```markdown
Phase-2-Architecture-réseau/
├─ Security-Onion/
│   ├─ installation/                # notes d'installation SO
│   ├─ configuration/               # snippets Suricata / chemins
│   ├─ scripts/                     # scripts installés sur Security Onion
│   │   ├─ call.sh                  # superviseur : relance script.sh si nécessaire
│   │   └─ script.sh                # parser Suricata -> Redis
│   └─ events/                      # exemples d'eve-*.json / extraits
│
├─ SOAR-Leger/
│   ├─ architecture/                # diagrammes + explications
│   ├─ scripts/
│   │   ├─ worker.py                # worker Redis -> n8n
│   │   ├─ .env.example             # variables d'environnement
│   │   └─ systemd/                 # unités systemd pour prod
│   │       ├─ soar-worker.service
│   │       └─ soar-caller.service
│   ├─ workflows/
│   │   ├─ n8n_block_workflow.json
│   │   └─ n8n_unblock_scheduler.json
│   └─ docs/                        # guide pfSense / webhooks / bonnes pratiques
│
└─ validation/
├─ eve_snippets/                # extraits d'événements Suricata
├─ logs_workers/                # logs bruts des workers
└─ demo_script_bruteforce.sh    # script PoC brute-force utilisé pour les tests

````

---

# 🧩 Description des composants

## 🔵 Security Onion — Suricata (sonde)
- Capture du trafic via port mirroring.
- Écrit des fichiers horodatés :  
  `eve-2025-11-26.json`, `eve-2025-11-26.json.1.gz`, etc.
- Les scripts gèrent :
  - la rotation,
  - la lecture progressive,
  - l’offset,
  - la comparaison de timestamps,
  - la détection de nouveaux fichiers.

### Scripts :
| Script | Rôle |
|-------|------|
| **script.sh** | Parse les eve-*.json*, extrait uniquement les nouvelles alertes, push dans Redis (`RPUSH so:alerts`). |
| **call.sh** | Superviseur : vérifie si `script.sh` tourne, redémarre si crash, nettoie les états. |

---

## 🔴 Redis — Buffer / File d’attente
Fonctionne comme un **tampon centralisé** :

- Liste principale : `so:alerts`
- Produit : `script.sh`
- Consommateurs : `worker.py` (x1 ou xN)
- Garantit durabilité + atomicité via BLPOP / RPOPLPUSH.

---

## 🟡 Workers Python — Automatisation résiliente
**worker.py** :

- Lit les événements depuis Redis (BLPOP).
- Transforme la charge JSON.
- Fait un `POST` vers le webhook n8n.
- Gère :
  - timeouts,
  - retries,
  - backoff exponentiel,
  - journalisation,
  - bascule en liste `so:failed` si échec.

Configuration via `.env` :

```env
REDIS_HOST=10.0.254.6
REDIS_PORT=6379
REDIS_PASSWORD=CHANGEME
N8N_WEBHOOK_URL=https://10.0.254.4:5678/webhook/XXXXXXXX
````

---

## 🟢 n8n — Moteur SOAR léger

Deux workflows :

### **1. n8n_block_workflow.json**

* Reçoit l’alerte (webhook).
* Extrait l’IP, le SID, le timestamp.
* Valide l’événement.
* Met à jour l’alias `autoblock` sur pfSense.
* Log complet.

### **2. n8n_unblock_scheduler.json**

* Exécution toutes les X minutes.
* Récupère l’alias `autoblock`.
* Supprime les IP expirées.
* Pousse l’alias mis à jour vers pfSense.

---

## 🟣 pfSense — Firewall (enforcement)

Un alias dynamique :

```
autoblock
```

Utilisé dans une règle bloquant :

```
IPv4 source in <autoblock>
```

Ce modèle permet :

* un état unique,
* un rollback simple,
* pas de duplication,
* pas de redémarrage du firewall.

---

# 🚀 Déploiement (résumé rapide)

### 1. Déploiement des scripts sur Security Onion

```
sudo mkdir -p /opt/soar
sudo cp script.sh call.sh /opt/soar/
chmod +x /opt/soar/*.sh
```

### 2. Déploiement worker

```
sudo cp worker.py /opt/soar/
sudo cp .env /opt/soar/
```

Installation des dépendances :

```
pip3 install redis requests python-dotenv
```

### 3. Activation systemd (exemples fournis)

```
sudo cp soar-worker.service /etc/systemd/system/
sudo cp soar-caller.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now soar-worker
sudo systemctl enable --now soar-caller
```

### 4. Import workflows n8n

Depuis l’interface n8n → **Import Workflow**.

---

# 🧪 Validation & Tests

### 1. Lancer un test brute-force

```
bash validation/demo_script_bruteforce.sh
```

### 2. Vérifier Redis

```
redis-cli LLEN so:alerts
```

### 3. Vérifier worker

```
journalctl -u soar-worker -f
```

### 4. Vérifier n8n

Webhook reçu + exécution du workflow.

### 5. Vérifier pfSense

Alias `autoblock` mis à jour → règle appliquée.

---

# ✔️ Critères d’acceptation

* Les alertes Suricata sont détectées **uniquement si > last_ts**.
* Pas de doublons dans Redis.
* Le worker consomme en temps réel.
* Le workflow n8n reçoit bien les événements.
* L’IP attaquante apparaît dans `autoblock`.
* Le scheduler supprime automatiquement les IP expirées.
* pfSense débloque après expiration.

---

# 📈 Améliorations futures

* GO script pour high performance ingestion.
* Export métriques Prometheus (longueur de queue, latence).
* mTLS entre worker ↔ n8n.
* Cluster Redis.
* Règles dynamiques Suricata enrichies (GEOIP / threat-feed).

---

# 🏁 Conclusion

Cette architecture met en place un pipeline **complet, robuste et open-source** permettant :
✔ Analyse réseau en temps réel
✔ Découplage ingestion / automatisation
✔ Résilience via Redis + workers multiples
✔ Actions réseau automatisées (pfSense)
✔ Système reproductible et documenté

Elle constitue la base d’un **SOAR maison** fiable et extensible, adapté aux environnements réels.

