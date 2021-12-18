## CommLab - Community Networking
##### Make your own home on the Internet.
CommLab is a project to assemble a fully-featured free communications and collaboration software distribution for Kubernetes that anyone can learn to use, administer, and contribute to. Its primary technical goals are to document, standardize, and unify implementations and integrations of free software. It will use this process to help more people concerned with community-controlled infrastructure to self-educate at accelerated pace to realize their goals through software, in ways previously only afforded to those who could dedicate their entire lives or massive teams of specialists to the work. Please excuse any omissions or errors, as this version of the readme was composed in a hurry to get the configs pushed, but watch this space this week for updates after I can run these instructions back through a testing environment.

##### Features & Contributions
- This is a good starting point on which to build your configuration, as well as customize & contribute
- As of now, Mastodon, PeerTube, and Matrix Synapse/Element are implemented with Keycloak SSO
- Includes our own self-hosted object storage system to prevent vendor lock-in with hosted services
- Currently configured to use three web/Mastodon nodes, one PeerTube node, and one Matrix node.
- Composed of mostly Helm charts, Kustomized manifests, and Docker-Compose configs.
- Using central operators to reduce repetitive configurations and likelihood of error
- Seeking to integrate the most reliable and best-documented approaches available for any given task
- Tested on commodity cloud providers with an eye toward enabling self-hosting co-ops & multi-cloud

##### Next Goals
Check the Projects tab for more.
- The distro is rough around the edges yet. There will be several updates in the next couple weeks.
- In that category, there are nodeSelectors left undefined, security features not yet enabled, and more.
- The most important missing feature is monitoring, and it takes top dev / testing priority right away.
- A load-balancing S3 read cache is on the way, and an API proxy may still be on the way as well. This would prevent vendor lock-in and application migration troubles no matter what provider you use.
- A Postfix SMTP server installation is called for to de-necessitate connecting existing email service.
- There is trouble getting PGO to initdb with POSIX encoding, so Bitnami PostgreSQL is used for now.
- That frontpage sure is a slapped-together pile of whew-boy! Thing needs some help!
- The next app to integrate is almost certainly a wiki, and next after that, a ticketing/support system.
- Split documentation into a README quickstart and technical docs for the experienced, and full walkthroughs & video guides for newcomers to Kubernetes or server administration generally

##### Big Thanks
This project would of course not be possible without the massive efforts of so many free software developers across the world. Projects whose insights, configurations, and code lent to this one include [peertube-k8s](https://github.com/coopgo/peertube-k8s), [peertube-on-kubernetes](https://forge.extranet.logilab.fr/open-source/peertube-on-kubernetes), [peertube-helm](https://git.lecygnenoir.info/LecygneNoir/peertube-helm), [peertubeexporter](https://gitlab.com/synacksynack/opsperator/docker-peertubeexporter/), [ananace-charts](https://gitlab.com/ananace/charts), and many more whom it will take time to catalogue as this repo is fleshed out and these disparate notes are exhausted of sources :)

Software used in the distribution includes [PeerTube](https://joinpeertube.org/) - [Mastodon](https://joinmastodon.org/) - [Matrix Synapse](https://matrix.org/docs/projects/server/synapse) - [Element Web](https://matrix.org/docs/projects/client/element) - [CrunchyData Postgres Operator v5](https://www.postgresql.org/about/news/pgo-the-crunchy-postgres-operator-v5-released-fully-declarative-postgres-2258/) - [Kubernetes NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/) - [cert-manager](https://cert-manager.io/) - [redis](https://hub.docker.com/_/redis/) - [Prometheus](https://prometheus.io/) - [Bitnami PostgreSQL](https://bitnami.com/stack/postgresql)

## Installations
All configurations use the original chart of the stated version, included for your convenience and availability, but for the purposes of security, you may instead pull the charts directly. Wherever you see "example" or "example.com", fill in your own domain name and instance name. The instance name is used throughout to maximally enable multi-tenancy but that may be overkill. A genericized version of our production values.yamls are provided throughout, but you should use these reference values to populate another copy of the original configuration files.

### System software
##### Kubernetes NGINX Ingress
To pull the chart yourself:
- `helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx`
- `helm repo update`
- `helm pull ingress-nginx/ingress-nginx:TAG`
- `tar -zxvf mychart.tgz`
Copy out and edit values.yaml with your replicaCount, nodeSelector, uncommenting the podAntiAffinity, Prometheus exporter, and TCP ports.
- `helm upgrade --install ingress-nginx ingress-nginx-VERSION/ -f values.yaml --namespace ingress-nginx --create-namespace`
- `kubectl get svc -o wide -n ingress-nginx`
Once the load balancer is finished provisioning, you can enter the external IP address into an A record in DNS for your anticipated domain names.

##### cert-manager
- `kubectl create namespace cert-manager`
To install from their servers:
- `kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.6.1/cert-manager.yaml`
There is no need to enter a deployment namespace manually for either copy:
- `kubectl apply -f cert-manager-VERSION.yaml`
Apply your ClusterIssuer suitable for wildcard certificates by using dnsZone

##### Crunchy Postgres Operator v5
If cloning it yourself, take careful note of what you download, because the new v5 examples repo isn't getting tags applied properly yet. It is best for troubleshooting purposes that you fork the original repo and clone from your own.
- Visit and fork [the repo](https://github.com/CrunchyData/postgres-operator-examples/fork)
- `git clone https://github.com/myUsername/postgres-operator-examples.git`
- `kubectl apply -k postgres-operator-examples/kustomize/install`
Note: Whenever you set up a database for testing purposes, enter a bogus S3 backup target endpoint until you're ready to start filling buckets, because initial creation triggers a backup of ~1250 files and delete operations can be very slow on some providers, complicating deletion and re-deployment. However, you may find some trouble enabling backup at some point after deployment as well, so don't consider a production deployment complete until you have completed your first backups.

##### Kube metrics server
We're going to need a way to watch resource usage until we get Prometheus working properly.
- `kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml`
- Check your overall resource usage with `kubectl top nodes` or `kubectl top pods`

### Minio Storage Setup
The topology is that of a main storage server taking uploads, and doing realtime server-side mirroring to a secondary site that will be soon load-balanced and cached for reads. You should also mirror that backup client-side to a disaster recovery site, perhaps at home or colocated nearby.

Configure your storage servers for a simple Docker-Compose installation and typical basic security measures. The provided configuration uses Docker as root which is probably more than sub-optimal, but non-root setup has some complications we'll have to revisit later. Configure certificate retrieval via Certbot and preferably a DNS-based solver, as HTTP would require webserver integration.

Edit the login and server values in docker-compose.yaml, comment out the mc01/02 services for now. Once installation is complete, you will add buckets and users to the minio instances, which are then entered into the mc replicating scripts. To get decent randomized passwords and access/secret keys use `openssl rand --base64 18` and `openssl rand --base64 36`

To provide for DNS bucket lookup, `MINIO_DOMAIN` specifies the [only!] domain that server is enabled with, and your certificate must include wildcards as Subject Alternate Names for all enabled domains. An example retrieval would be:
- `sudo certbot certonly --expand --dns-myprovider --dns-myprovider-api-key ~/certbot-creds.ini -d 'io.example.com' -d '*.io.example.com' -d '*.region2.io.example.com' -d '*.region1.io.example.com' -d '*.api.io.example.com'`

### Keycloak installation
##### Values to fill
postgres.yaml etc.
- Edit your S3 accessKey and secretKey for backups
- Set your nodeSelector for both the database and pgBouncer
- Enter your S3 bucket details and customize schedule
- Set your storageClassName, set your resource requests and limits
values.yaml
- Enter adminPassword and managementPassword
- TLS enabled and autoGenerated (to get JKS keystore key)
- Enter your nodeSelector and podAntiAffinity
- Enter all your Ingress details, with host and secret
- ServiceMonitor remains disabled until Prometheus is ready.
- Fill in externalPostgresql with details decoded from PGO's "pguser" generated secret using `echo '' | base64 --decode`
##### Deployment
kubectl apply -k postgres-db
- `helm upgrade --install example-login keycloak-VERSION/ -f values.yaml -n example-login`
- Open up login.example.com, enter your admin login, and create a Realm for your site.

### Mastodon installation
CommLab is contributing additional features to the Mastdon helm chart, such as single-sign-on and WEB_DOMAIN functionality, and may also include additional specific features of no interest to the mainline chart, so that fork is duplicated here and available on [this github repo](https://github.com/bobbyd0g/mastodon/tree/main/chart).
##### Values to fill
postgres.yaml etc.
- Same as with login, but for the Mastodon installation. Both use the same high availability setup.
values.yaml
- Admin name/email, local_ and web_ domain environment variables (see commented documentation)
- Your S3 login details and admin email SMTP
Generate your secrets and VAPID keys:
- `docker run -it tootsuite/mastodon:VERSION /bin/bash`
- `bundle exec rake mastodon:setup`
- Domain name should be your LOCAL_DOMAIN. You are using Docker, don't need to set up / retry PG/redis.
- Spin up your database with `kubectl apply -k postgres-db`
- Back to values.yaml, enter your Ingress details, database password from pguser secret
- Enter a Redis password, resource requests and nodeSelector
- You can obtain your IDP_CERT from the "SAML Metadata" button in your Keycloak Realm settings, or under Keys, in the RS256 SIG certificate.
Edit and use redirect-wellknown.yaml if you have no front page up to forward federation endpoints, otherwise copy their configuration snippet into your Ingress.
##### Deployment
- `helm upgrade --install example-mastodon chart/ -f values.yaml --namespace example-mastodon`
You might have to do this a bunch of times. Sometimes the redis pods get suck, sometimes volumes don't want to bind right away, it's a bunch of stuff to bring up at once. Note that elasticsearch is disabled, which made deployment with one Helm chart all but impossible. Deployments time out after five minutes and Helm fails to trigger the post-install hooks. So, make sure your config is really right 
- Do a "forgot password" for your admin account, log in, and shut off new registrations.
##### Keycloak-side config
- Client ID: mastodon
- Include AuthnStatement, Sign Documents, Sign Assertions
- If you omit your client-side cert from the Mastodon config, which I will document once the new testing environment goes up, set Client Signature Required to OFF.
- Canonicalization method: Exclusive
- Root URL and Base URL: https://mastodon.example.com
- Valid Redirect URI: https://mastodon.example.com/auth/auth/saml/callback
Mappers configured as so:
- All "User Property" of the "Basic" type, the names are your choice
- property "uid" to SAML attribute "uid"
- property "email" to SAML attribute "email"
- property "firstName" to SAML attribute "first_name"
- property "lastName" to SAML attribute "last_name"

### PeerTube installation
You can tell this is pasted in from something more complete, but also older, and you'll see why the PeerTube config is about to be converted to a Helm chart. Note also we disable high availability for the database, just one replica and no proxy.
##### Values to fill
- Edit `peertube/kustomization.yaml` with configuration for your instance. The patches toward the bottom allow us to keep most of our edits neatly confined to this file. Choose a unique namespace and label, especially if planning to run multiple instances. Look for the `value` you want to change, usually the last line(s).
- Choose a nodeSelector that uniquely identifies the node you want this to run on. Your cloud provider will use some kind of `/metadata/labels/` that identifies the node pool it belongs to.
- Patch in the correct hostname for your instance, and the ClusterIssuer you set up for cert-manager.
- Edit `pvc.yaml` with a storageClass that will `retain` detached volumes in case there's a problem.
- Edit `postgres-db/kustomization.yaml` with the same namespace and labels. S3 creds go in `s3.conf`
- Edit `postgres.yaml` with the same `retain` -policy storageClass and nodeSelector (which is here broken out into `matchExpressions/key` and `matchExpressions/value`)
- Your backup schedule is configured here by default to retain a backup set (a full and its incrementals) for 22 days under `repo1-retention-full` -- and using cron formatting under `schedules` below, for a default full weekly backup at 2am Monday morning and daily incrementals at 1am.
##### Deployment
- Create your namespace with `kubectl create namespace example-peertube`
- Bring up the database with `kubectl apply -k postgres-db` and give it a few minutes to become Ready.
- Bring up the website with `kubectl apply -k peertube` and look out for errors. Use `kubectl describe pod PODNAME` and `kubectl logs pod/PODNAME peertube` for troubleshooting.
- Get the root password from logs
```
kubectl get pod -n peertube
kubectl logs peertube-pod peertube | grep -A1 root
```
If you're having problems, you'll need to tear down both peertube with `kubectl delete -k peertube` and the database with `kubectl delete -k postgres-db` to do a clean re-initialization.

### Matrix installation
##### Values to fill
postgres.yaml etc.
- storageClassName, names
- Bring up the database for auth secret
synapse-values.yaml
- Name replacement performed to maintain unique release name without repetitive resource names.
- serverName / publicBaseURLServerName are a similar configuration to Mastodon's LOCAL/WEB_DOMAIN.
- Various passwords, keys, macaroonSecretKey
- SSO OIDC configuration, including secrets you generate per [Synapse documentation](https://matrix-org.github.io/synapse/develop/openid.html)
element-values.yaml
- defaultServer, Ingress, nodeSelectors throughout, wellknown details
- externalPostgresql filled with values from PGO pguser secret, a Redis password
- The chart does not address some pods' StorageClasses, which we will get back around to
##### Deployment
- `helm upgrade --install example-matrix-postgres bitnami-postgres --namespace example-matrix -f values.yaml`
- `helm upgrade --install synapse charts/charts/matrix-synapse --namespace example-matrix -f values.yaml`
Create an admin user:
```
kubectl exec --namespace matrix synapse-matrix-synapse -- register_new_matrix_user -c /synapse/config/homeserver.yaml -c /synapse/config/conf.d/secrets.yaml -u USERNAME -p PASSWORD --admin http://localhost:8008
```
- `helm upgrade --install element charts/charts/element-web/ --namespace example-matrix -f element-values.yaml`
##### Keycloak-side configuration
- Valid Redirect URI: `https://matrix.example.com/_synapse/client/oidc/callback`

### Frontpage assembly
Sorry about the index.htm for now. Make sense of this mess to your satisfaction and build the container:
- `docker build -t myUsername/example-frontpage:v0.4.2 .`
- `docker login`
- `docker push myUsername/example-frontpage:v0.4.2`
- `kubectl apply -f .`

## Party time