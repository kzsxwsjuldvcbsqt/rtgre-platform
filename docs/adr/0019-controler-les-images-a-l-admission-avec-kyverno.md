# 0019. Contrôler les images à l'admission avec Kyverno

- Statut : accepté
- Date : 2026-11-22

## Contexte

L'image du site est signée par le workflow qui la construit, et la CI de ce dépôt vérifie cette signature avant toute fusion. Rien ne la vérifie dans le cluster : qui écrit dans l'API de Kubernetes sans passer par le dépôt, ou fusionne malgré une CI en échec, peut faire tourner une autre image.

Les contraintes :

- les identités attendues restent écrites à un seul endroit, que la CI et le cluster lisent tous deux ;
- le nœud de travail a 6 Go de mémoire, dont 2,3 sont occupés ;
- comme tout composant, celui-ci ne doit pas apporter plus de vulnérabilités qu'il n'en évite ;
- une panne du contrôle ne doit pas arrêter le cluster.

## Options envisagées

### Politiques d'admission natives de Kubernetes

Aucun composant à déployer : l'API évalue elle-même des expressions CEL. Mais une expression ne peut ni joindre un registre ni vérifier une signature. Elle peut seulement exiger un dépôt et une empreinte.

### policy-controller de Sigstore

Fait pour cela, et rien d'autre : un seul pod. Mais son image porte plus de cinquante vulnérabilités HIGH ou CRITICAL, dans la version du chart (61) comme dans la dernière publiée (53). Le chart a deux versions de retard sur l'application, et lance une tâche avec une image au tag `latest`.

### Kyverno

Un moteur de politiques généraliste : 22 CRD, et quatre contrôleurs dont un seul sert ici. Son image porte une vulnérabilité HIGH. Ses politiques d'images vérifient une signature cosign sans clé, avec l'identité et l'émetteur attendus.

## Décision

Kyverno pour la signature, réduit à son contrôleur d'admission, et une politique native pour ce qui n'en a pas besoin.

- **Deux contrôles dans les espaces de noms étiquetés.** L'API de Kubernetes n'y admet que des images de dépôts déclarés, référencées par leur empreinte. Kyverno vérifie ensuite la signature de celles qui doivent en porter une.
- **Une seule liste des signataires**, `kubernetes/kyverno/files/signed-images.txt` : le chart en tire une politique par ligne, et la CI la lit pour sa propre vérification.
- **Refuser plutôt que laisser passer** : si Kyverno ne répond pas, ou ne joint pas le registre, le pod est refusé.
- **Kyverno n'est appelé que pour les espaces de noms étiquetés**, aujourd'hui celui du site. Ailleurs, sa panne ne bloque rien.
- **Il ne peut joindre que le registre des images signées et Sigstore**, pour ses certificats racines.
- **Mesure** : 57 Mo au repos, 67 Mo pendant les vérifications, une réponse en 200 ms.

## Conséquences

- Vérifié à la mise en service, sans créer de pod : une image signée par une autre branche, une image non signée, une image sans empreinte et une image d'un dépôt non déclaré sont refusées, chacune avec un message qui dit pourquoi. Les tâches du site passent.
- **La création d'un pod du site dépend maintenant de Kyverno, du registre et de Sigstore.** Si l'un manque, le site reste servi par le pod en place, mais n'est plus régénéré : l'alerte `GenerationEnEchec` part après trois heures, et `CibleInjoignable` signale l'arrêt de Kyverno. Avant, un pod pouvait démarrer avec l'image déjà présente sur le nœud.
- nginx n'est pas signé par son éditeur : son dépôt est admis sans signature, par empreinte.
- Un administrateur du cluster peut toujours retirer l'étiquette ou la politique. Le contrôle protège contre une erreur ou un contournement de la CI, pas contre lui.
- Sur un cluster qui vient d'être reconstruit, les premiers pods du site sont créés avant que Kyverno ne soit déployé : ceux-là ne sont vérifiés que par la CI. Constaté à la reconstruction du 22 novembre 2026.
- Les images posées par Ansible et kubeadm ne sont pas contrôlées : leurs espaces de noms ne sont pas étiquetés.
- Les tâches de migration du chart sont désactivées : une montée de version demande de lire ses notes, et attend une approbation.
- Retirer Kyverno demande de supprimer ses webhooks à la main ([README](../../kubernetes/kyverno/README.md)).
- **Vulnérabilité connue** : une, dans l'image de Kyverno, la même que dans cert-manager. Exception datée dans `.trivyignore.yaml`.
