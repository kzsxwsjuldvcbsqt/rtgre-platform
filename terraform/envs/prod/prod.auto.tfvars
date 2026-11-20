# Paramètres de l'environnement de production. Ils ne contiennent aucun secret et sont suivis par Git ;
# ce qui dépend du poste (authentification, namespace) reste dans terraform.tfvars.
name                 = "rtgre-platform-prod"
vcn_cidr             = "10.20.0.0/16"
vcn_dns_label        = "rtgreprod"
subnet_newbits       = 8
subnet_netnums       = { load_balancer = 10, nodes = 20 }
public_ingress_cidrs = ["0.0.0.0/0"]
