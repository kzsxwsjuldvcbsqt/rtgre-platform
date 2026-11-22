# Post-mortems

Un incident en production se conclut par un post-mortem : ce qui s'est passé, pourquoi, et ce qui change pour que cela ne se reproduise pas. Il cherche des causes, pas des coupables.

| Date | Incident | Durée |
| --- | --- | --- |
| 2026-11-21 | [rtgre.fr sans certificat valide pendant la bascule](2026-11-21-bascule-sans-certificat.md) | 9 minutes |

## En écrire un

1. Pendant l'incident, tenir la chronologie dans l'issue « Incident » : elle sert de brouillon.
2. Dans les jours qui suivent, copier [`template.md`](template.md) en `AAAA-MM-JJ-sujet.md`, le remplir, et l'ajouter au tableau ci-dessus.
3. Ouvrir une issue pour chaque action retenue, et les lier depuis le post-mortem. Lier le post-mortem depuis l'issue de l'incident, puis la fermer.

Un post-mortem tient sur une page. S'il n'y a rien à changer, le dire : c'est aussi une conclusion.
