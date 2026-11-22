# Rôle `hardening`

Socle de sécurité appliqué à chaque nœud Ubuntu 24.04, avant toute installation de Kubernetes.

| Domaine | Ce que fait le rôle |
| --- | --- |
| SSH | Clé publique uniquement, pas de root, comptes autorisés limités (`AllowUsers`), redirections désactivées. Fichier `/etc/ssh/sshd_config.d/10-hardening.conf`, validé par `sshd -t`. |
| Pare-feu | ufw en refus par défaut. SSH, les plages de confiance et les ports publics demandés sont autorisés. Les règles iptables chargées par les images Oracle (`iptables-persistent`) sont retirées. |
| Mises à jour | `unattended-upgrades`, limité aux mises à jour de sécurité. Le redémarrage automatique, désactivé par défaut, se règle avec son heure. |
| Redémarrage attendu | La métrique `node_reboot_required`, écrite pour node-exporter par une minuterie systemd. |
| Noyau | Paramètres de `hardening_sysctl` écrits dans `/etc/sysctl.d/60-hardening.conf`. |

Toutes les variables sont dans `defaults/main.yml` et décrites dans `meta/argument_specs.yml`, qu'Ansible vérifie à chaque exécution.

## Choix notables

- **Le fichier SSH est préfixé par 10** : sshd retient la première valeur lue pour une option, et l'image apporte déjà `60-cloudimg-settings.conf`.
- **`/run/sshd` est créé par le rôle** : avec l'activation par socket d'Ubuntu 24.04, il n'existe qu'après la première connexion, et `sshd -t` échoue sans lui.
- **Le redémarrage automatique est une décision de l'inventaire**, pas du rôle : un nœud qui redémarre coupe ce qu'il porte. L'inventaire de la prod l'active, à des heures décalées ([ADR 0023](../../../docs/adr/0023-redemarrer-les-noeuds-seuls-la-nuit.md)).
- **`AllowTcpForwarding no`** par défaut : un nœud ne sert pas de rebond. `hardening_ssh_extra_options` permet une exception par groupe. Le plan de contrôle en a une seule : la redirection locale vers le port de la boucle locale où s'ouvre l'interface d'Argo CD (`AllowTcpForwarding local` et `PermitOpen`), voir [acceder-a-argocd](../../../docs/runbooks/acceder-a-argocd.md).
- **Pas de règle sur le routage** (`ip_forward`) : il relève du rôle qui prépare Kubernetes.

## Exemple

```yaml
- name: Harden the nodes
  hosts: all
  become: true
  roles:
    - role: hardening
      vars:
        hardening_firewall_trusted_cidrs:
          - 10.20.0.0/16
```

## Tests

```bash
cd ansible/roles/hardening
molecule test
```

Le scénario tourne dans un conteneur Ubuntu 24.04 avec systemd, construit depuis l'image officielle épinglée par empreinte, et privilégié pour faire tourner ufw. Avant le rôle, il installe `iptables-persistent` comme sur les images Oracle. Il vérifie ensuite :

- un second passage sans changement (idempotence) ;
- la configuration effective de sshd (`sshd -T`) ;
- les règles d'ufw ;
- les paquets ;
- les fichiers de mises à jour et de paramètres noyau.

Le conteneur partage le noyau de la machine hôte : les paramètres noyau y sont écrits mais pas appliqués (`hardening_sysctl_apply: false`).

Sur le poste, Molecule a besoin de Docker et de `rsync`.
