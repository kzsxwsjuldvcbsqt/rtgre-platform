# Se connecter à un nœud

Les nœuds n'acceptent aucune connexion depuis Internet ([ADR 0006](../adr/0006-sortir-par-la-passerelle-internet-sans-nat.md)). SSH passe uniquement par le service Bastion d'Oracle, avec une session de redirection de port vers le port 22 de chaque nœud.

## Prérequis

- Les outils de `mise.toml` et un profil `~/.oci/config` autorisé à créer des sessions sur le Bastion.
- La clé de la plateforme : `~/.ssh/id_ed25519_rtgre_platform` et sa partie publique. Une autre clé peut être indiquée avec `RTGRE_SSH_KEY`.
- `terraform/envs/prod` initialisé : le script lit le Bastion et les nœuds dans ses sorties.

## Ouvrir les sessions

Depuis la racine du dépôt :

```bash
scripts/bastion-ssh-config.sh
```

Le script ouvre une session par nœud, attend qu'elles soient actives (une trentaine de secondes), puis écrit `ansible/.ssh/bastion.conf`. Ce fichier n'est pas suivi par Git. Les sessions durent 3 heures : il suffit de relancer le script ensuite.

## Se connecter

```bash
ssh -F ansible/.ssh/bastion.conf cp-1
```

Pour Ansible, rien de plus à faire : `ansible.cfg` utilise déjà ce fichier.

```bash
cd ansible
ansible all -m ansible.builtin.ping
```

## En cas d'échec

| Symptôme | Cause probable |
| --- | --- |
| Le script indique qu'une session n'est pas active | Le Bastion ne joint pas le port 22 du nœud : vérifier la règle SSH du NSG des nœuds (depuis l'adresse du Bastion) et la sortie TCP 22 de la liste de sécurité du sous-réseau. |
| `Permission denied (publickey)` | La clé publique de la session ne correspond pas à la clé privée utilisée, ou le compte n'est pas `ubuntu`. |
| La connexion fonctionnait puis échoue | La session a expiré : relancer le script. |

## Pourquoi la redirection de port

Les sessions SSH « gérées » du Bastion passent par le plugin Bastion de l'agent Oracle Cloud. Sur les images Ubuntu, ce plugin s'annonce comme `RUNNING` mais ne laisse aucune trace sur le nœud, et les sessions restent bloquées en `CREATING` (essai du 2026-11-21). Les sessions de redirection de port n'en dépendent pas : elles sont actives en quelques secondes. Le plugin reste donc désactivé.
