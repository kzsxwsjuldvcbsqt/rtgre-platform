"""Redémarre le serveur web par un déploiement progressif, sans coupure.

Les journaux d'un pod sont supprimés avec lui : remplacer le pod chaque semaine borne leur
conservation (ADR 0014). Le script fait ce que fait « kubectl rollout restart », avec la seule
bibliothèque standard : il date une annotation du gabarit de pod.
"""

import datetime
import json
import os
import ssl
import urllib.request

ACCOUNT = "/var/run/secrets/kubernetes.io/serviceaccount"

with open(f"{ACCOUNT}/namespace", encoding="utf-8") as handle:
    namespace = handle.read()
with open(f"{ACCOUNT}/token", encoding="utf-8") as handle:
    token = handle.read()

deployment = os.environ["DEPLOYMENT"]
api = f"https://{os.environ['KUBERNETES_SERVICE_HOST']}:{os.environ['KUBERNETES_SERVICE_PORT']}"
now = datetime.datetime.now(datetime.UTC).strftime("%Y-%m-%dT%H:%M:%SZ")
patch = {"spec": {"template": {"metadata": {"annotations": {"kubectl.kubernetes.io/restartedAt": now}}}}}

request = urllib.request.Request(
    f"{api}/apis/apps/v1/namespaces/{namespace}/deployments/{deployment}",
    data=json.dumps(patch).encode(),
    method="PATCH",
    headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/strategic-merge-patch+json",
    },
)
context = ssl.create_default_context(cafile=f"{ACCOUNT}/ca.crt")
with urllib.request.urlopen(request, context=context, timeout=30) as response:
    generation = json.load(response)["metadata"]["generation"]

print(f"{deployment} : redémarrage demandé à {now} (génération {generation})")
