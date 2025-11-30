# Installation de VyOS

Cette section décrit le déploiement et la configuration initiale de VyOS pour le laboratoire d’infrastructure réseau (Phase 1).

---

## a) Démarrage de l’ISO VyOS

1. Créer une nouvelle VM (Linux 64-bit, 2 CPU, 1–2 GB RAM).  
2. Monter l’ISO VyOS dans la VM.  
3. Démarrer la VM pour accéder au système VyOS en mode live.

---

## b) Installation du système

1. Lancer la commande d’installation :
```bash
install image
```
Suivre les instructions à l’écran.
Choisir les options par défaut (recommandé pour ce laboratoire).
Redémarrer la VM sans l’ISO.

## c) Configuration des interfaces réseau

Exemple de configuration selon le plan d’adressage fourni :
```bash
configure
```
```bash
set interfaces ethernet eth0 address 10.0.1.1/30
```
```bash
set interfaces ethernet eth1 address 10.0.254.1/24
```
```bash
set interfaces ethernet eth2 address 10.0.10.1/24
```
```bash
commit
```
```bash
save
```
```bash
exit
```
| Zone            | Sous-réseau          |
|----------------|-----------------------|
| **eth0**  | `Core link vers pfSense`         |
| **eth1** | `ssh`       |
| **eth2**        | `Distribution/Access `         |


## d) Preuve de bon fonctionnement (PoC)

```bash
ssh vyos@10.0.254.1
```

<img width="996" height="700" alt="image" src="https://github.com/user-attachments/assets/b116ab6a-8e0e-41d8-8903-b2effc0301bd" />

#### PoC VyOS — Connectivité Phase 1

Toutes les interfaces configurées sont opérationnelles :

  <img width="1178" height="222" alt="image" src="https://github.com/user-attachments/assets/2848ce56-f721-4449-a518-666c8a6439dc" />
  
La table de routage reflète toutes les sous-réseaux et le défaut vers pfSense :

<img width="957" height="373" alt="image" src="https://github.com/user-attachments/assets/8391755c-ec72-4bce-9ccc-9e590a998827" />

Test de connectivité interne et externe :

<img width="838" height="193" alt="image" src="https://github.com/user-attachments/assets/56e22c98-2f26-43bd-b195-c719ab62503c" />
<img width="808" height="250" alt="image" src="https://github.com/user-attachments/assets/225b840c-6528-4e59-b5c8-5414715ff70e" />
<img width="842" height="477" alt="image" src="https://github.com/user-attachments/assets/920b0c4a-8bce-48d1-a57a-47b95396b631" />
<img width="1917" height="320" alt="image" src="https://github.com/user-attachments/assets/962982bb-52f2-4801-87d9-9ffbfe480589" />

