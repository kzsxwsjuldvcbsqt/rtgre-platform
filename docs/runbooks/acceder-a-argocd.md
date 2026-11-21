# Accéder à Argo CD

L'interface d'Argo CD n'est exposée ni à Internet ni au réseau virtuel ([ADR 0010](../adr/0010-deployer-en-gitops-avec-argo-cd.md)). Elle s'ouvre par deux redirections de port en chaîne : SSH jusqu'au plan de contrôle à travers le Bastion, puis `kubectl` jusqu'au service.

## Ouvrir l'interface

Depuis la racine du dépôt, après avoir ouvert les sessions du Bastion ([se-connecter-a-un-noeud](se-connecter-a-un-noeud.md)) :

```bash
ssh -t -F ansible/.ssh/bastion.conf -L 8080:127.0.0.1:8080 cp-1 kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Puis ouvrir <https://localhost:8080>. Le certificat est autosigné : le navigateur demande de l'accepter. `Ctrl+C` ferme tout.

- L'option `-t` compte : sans elle, la redirection `kubectl` continue de tourner sur le nœud après la déconnexion.
- Si le port 8080 est déjà pris sur le poste, changer seulement le premier nombre : `-L 8443:127.0.0.1:8080`, puis <https://localhost:8443>.
- Le second nombre ne se change pas : sshd n'autorise la redirection que vers ce port du plan de contrôle (`platform_argocd_forward_port`).

## Première connexion

Le compte est `admin`. Son mot de passe initial est généré à l'installation :

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

1. Se connecter, puis changer le mot de passe dans « User Info », « Update password ». Le ranger dans un gestionnaire de mots de passe.
2. Supprimer le secret initial, devenu inutile :

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n argocd delete secret argocd-initial-admin-secret
```

## Lire l'état sans l'interface

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n argocd get applications
```

Chaque application doit être `Synced` et `Healthy`. Le détail d'une erreur se lit dans ses conditions :

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n argocd describe application root
```

## Mot de passe perdu

Remettre le mot de passe à zéro fait régénérer un mot de passe initial au redémarrage du serveur :

```bash
ssh -F ansible/.ssh/bastion.conf cp-1 "kubectl -n argocd patch secret argocd-secret --type json -p '[{\"op\":\"remove\",\"path\":\"/data/admin.password\"},{\"op\":\"remove\",\"path\":\"/data/admin.passwordMtime\"}]'"
ssh -F ansible/.ssh/bastion.conf cp-1 kubectl -n argocd rollout restart deployment argocd-server
```

Reprendre ensuite à « Première connexion ».
