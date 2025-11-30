# pfSense — Installation, configuration et PoC (Phase 1)

## Résumé
Cette page décrit le déploiement de pfSense en tant que pare-feu périmétrique de la Phase 1 : installation ISO, assignation des interfaces, règles minimales (DMZ / Management), routage statique vers VyOS et méthode pour exporter un `pfsense-config.xml` purgé à des fins de documentation.

> Objectif PoC : démontrer que pfSense est correctement installé, que les interfaces sont joignables, que les routes statiques sont présentes et que la politique DMZ/Management fonctionne.

---

## 0) VM & ressources 
- VM type : FreeBSD / Other (pfSense template if available)  
- CPU : 1 vCPU   
- RAM : 1 GB 
- Disk : 4 GB  
- NICs : 4 (WAN, Core, DMZ, Management) — mapper sur Host-Only / NAT selon test

---

## 1) Installation pfSense (ISO)

1. Créer une VM (type FreeBSD 64-bit).  
2. Monter l'ISO pfSense (image officielle).  
3. Démarrer la VM, lancer l’installation standard (`Install`) → suivre l’assistant.  
   - Partitionnement automatique (UFS) ou ZFS si RAM suffisante.  
4. Valider et redémarrer la VM une fois l’install terminée.  
5. Sur le premier boot, pfSense proposera d’assigner les interfaces réseau (`em0`, `em1`, `em2`, `em3`). Attribuer selon la table ci-dessous.

---

## 2) Nomination & mapping des interfaces

| pfSense | Usage      | Host-Only / Réseau |
|--------:|------------|---------------------|
| `em0`   | WAN        | NAT / Internet (dhcp) |
| `em1`   | Core       | 10.0.1.2/30         |
| `em2`   | DMZ        | 10.0.4.1/24         |
| `em3`   | Management | 10.0.254.2/24       |

> **Important** : activer l’option *anti-lockout* ou créer une règle Management explicite pour éviter de se verrouiller hors de l’UI pendant les tests.

---

## 3) Configuration initiale via GUI

1. Ouvrir la GUI depuis une machine du réseau `Management` :  
   `https://10.0.254.2/`  
   - Login : admin (ou compte créé à l’installation) — **changer le mot de passe immédiatement**.

2. **System → General Setup**  
   - Hostname, Domain, DNS (si nécessaire), Timezone.

3. **System → Advanced**  
   - Activer HTTPS, vérifier mode webConfigurator (TLS).
   - Activer *anti-lockout* si tu veux garder le port 443 accessible management.

4. **Interfaces → Assign**  
   - Vérifier que `em0/em1/em2/em3` sont bien mappés et ont les bonnes IPs.  
   - Si besoin : *Interfaces → [emX] → Static IPv4* pour définir l’IP.

5. **System → Routing → Gateways**  
   - Ajouter une gateway vers `10.0.1.1` (VyOS) si pfSense doit joindre les sous-réseaux internes via VyOS.

6. **System → Routing → Static Routes**  
   - Ajouter :
     - Destination : `10.0.2.0/24` → Gateway : `10.0.1.1`
     - Destination : `10.0.3.0/24` → Gateway : `10.0.1.1`

7. **Firewall → Rules** (règles minimales recommandées)
   - **Management (em3)** :
     - Allow : `ManagementNet` → `This firewall (self)` ports `443,22` (administration)
   - **DMZ (em2)** :
     - Allow : DMZ → WAN ports `80,443` (si tu publies des services)
     - Deny : DMZ → Management (par défaut : refuser)
   - **WAN** :
     - Minimal NAT/Port-Forward si tu publies un service DMZ

8. **Firewall → NAT → Outbound**  
   - Mode automatique suffit pour un lab. Si tu utilises NAT manuel, créer mapping source `10.0.2.0/24` -> WAN.

9. **Diagnostics → Backup & Restore**  
   - Télécharger le `config.xml` localement pour archivage **avant** toute modification critique.

---

## 4) PoC — commandes & vérifications à exécuter (captures)

### a) Vérifier interfaces & IP (GUI)
- **Status → Interfaces** : capture d’écran montrant `em0/em1/em2/em3` UP et IPs assignées.

### b) Ping via GUI (Diagnostics → Ping)
- Tester : `10.0.1.1` (VyOS), `10.0.254.1` (VyOS management), `8.8.8.8` (Internet)
- Capture d’écran : résultat OK (0% loss).

### c) Vérifier routes (CLI/SSH)
Se connecter en SSH au shell pfSense (`Diagnostics → Command Prompt` ou `SSH`) et exécuter :
```sh
# routes (FreeBSD)
netstat -rn

# afficher règles pf (pfSense)
pfctl -sr       # affiche règles
pfctl -s state  # affiche états de session (si connexions en cours)
