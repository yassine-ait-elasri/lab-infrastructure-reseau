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
<br/>
<p align="center"><img  width="718" height="406" alt="image" src="https://github.com/user-attachments/assets/c0e2a3c1-f7a8-46f6-8a97-379dd93192c7" /></p>

> **Important** : activer l’option *anti-lockout* ou créer une règle Management explicite pour éviter de se verrouiller hors de l’UI pendant les tests.

---

## 3) Configuration initiale via GUI

1. Ouvrir la GUI depuis une machine du réseau `Management` :  
   `https://10.0.254.2/`  ( ou `http://10.0.254.2/` )
   - Login : admin (ou compte créé à l’installation) — **changer le mot de passe immédiatement**.

     <img width="1912" height="702" alt="image" src="https://github.com/user-attachments/assets/51dee329-ceba-4c22-a5ce-b44a38208c64" />


1. **System → General Setup**  
   - Hostname, Domain, DNS (si nécessaire), Timezone.
<img width="1235" height="818" alt="image" src="https://github.com/user-attachments/assets/73425364-a80e-4dc6-b5ec-48feb66066a3" />

2. **System → Advanced**  
   - choisit  HTTP/HTTPS.
   - Activer *anti-lockout* si tu veux garder pfsense accessible pour management.
<img width="1907" height="632" alt="image" src="https://github.com/user-attachments/assets/37ec77ee-005f-4d95-880a-3f361eef60de" />

3. **Interfaces → Assign**  
   - Vérifier que `em0/em1/em2/em3` sont bien mappés et ont les bonnes IPs.  
   - Si besoin : *Interfaces → [emX] → Static IPv4* pour définir l’IP.
<img width="1918" height="452" alt="image" src="https://github.com/user-attachments/assets/512b06b5-5dc9-435d-908c-c1fa9a4cbe2d" />
<br/> interfaces : IPs
<p></p>
<img width="1918" height="452" alt="image" src="https://github.com/user-attachments/assets/7dc2551c-8087-4d50-91f4-0bc6775917f8" />

4. **System → Routing → Gateways**  
   - Ajouter une gateway vers l'internet :
<img width="1642" height="216" alt="image" src="https://github.com/user-attachments/assets/f523659d-3e28-4cea-a732-973b726d57a6" />


5. **Firewall → Rules** (règles minimales recommandées)
   - **Management (em3)** :
     - Allow : `ManagementNet` → `This firewall (self)` ports `443,22` (administration)
<img width="1907" height="632" alt="image" src="https://github.com/user-attachments/assets/37ec77ee-005f-4d95-880a-3f361eef60de" />

   - **DMZ (em2)** :
     - Allow : DMZ → WIFI INTERFACE `WIFI INTERFACE` ( pour un accès externe ou dmz'
     - Allow : DMZ → DMZ_INTERFACE `WIFI INTERFACE` ( pour les mis à jours '
     - Deny : DMZ → Management (par défaut : refuser)
     - Deny : DMZ → LAN (par défaut : refuser)
<img width="1365" height="576" alt="image" src="https://github.com/user-attachments/assets/3947affb-b1a2-4be5-aa78-7043ab63fffb" />

   - **WAN** :
     - Minimal NAT/Port-Forward si tu publies un service DMZ
<img width="1318" height="447" alt="image" src="https://github.com/user-attachments/assets/19cb5959-2154-4f42-8df8-586281180ea6" />

6. **Firewall → NAT → Outbound**  
   - Mode automatique suffit pour un lab. Si tu utilises NAT manuel, créer mapping source `10.0.2.0/24` -> WAN.
<img width="1242" height="842" alt="image" src="https://github.com/user-attachments/assets/34ec25d8-63c9-4e24-8f9e-2ba7020399a3" />

7. **Diagnostics → Backup & Restore**  
   - Télécharger le `config.xml` localement pour archivage **avant** toute modification critique.
<img width="1915" height="631" alt="image" src="https://github.com/user-attachments/assets/10c0419e-15fe-4027-ba1d-c044be015da3" />

---

## 4) PoC — commandes & vérifications à exécuter (captures)

### a) Vérifier interfaces & IP (GUI)
- **Status → Interfaces** : capture d’écran montrant `em0/em1/em2/em3` UP et IPs assignées.
<p align="center"><img width="731" height="907" alt="image" src="https://github.com/user-attachments/assets/65e522fa-ac61-4b96-afcc-f9927856d7b3" /></p>

### b) Ping via GUI (Diagnostics → Ping)
- Tester : `10.0.1.1` (VyOS), `10.0.254.1` (VyOS management), `8.8.8.8` (Internet)
- Capture d’écran : résultat OK (0% loss).
<img width="1471" height="868" alt="image" src="https://github.com/user-attachments/assets/65cb4e03-5520-4444-9c2e-9b958a6e145c" />

### c) Vérifier routes (CLI/SSH)
Se connecter en SSH au shell pfSense (`Diagnostics → Command Prompt` ou `SSH`) et exécuter :
```sh
# routes (FreeBSD)
netstat -rn

# afficher règles pf (pfSense)
pfctl -sr       # affiche règles
pfctl -s state  # affiche états de session (si connexions en cours)
```
<img width="1447" height="951" alt="image" src="https://github.com/user-attachments/assets/fe408b1e-dfe3-42aa-98ca-084267cfa762" />
<img width="1447" height="951" alt="image" src="https://github.com/user-attachments/assets/e16e75b1-93c5-47e4-959d-a04a208a31b0" />
