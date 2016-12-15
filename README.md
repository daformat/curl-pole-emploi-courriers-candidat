# Curl Pôle emploi / courriers candidat

## Welcome to pôle emploi!
A zsh script to log-in to pole-emploi from the command-line, and download pdf "courriers" files to the current directory using curl and a few other unix friends.

`./pe-curl.sh [--conf configuration-file] [--id identifier] [--pass password] [--zip zipcode] [--pdf-dir path-to-pdf] [--imsg phone] [--shut-the-fuck-up]`

## Bienvenue à pôle emploi !
J'en avais marre de devoir me taper toutes les étapes de connexion sur pôle-emploi juste pour aller vérifier si j'avais reçu du nouveau courrier (leur système de notification mail n'est vraiment pas fiable et prévient parfois trop tard, voir pas du tout quand un nouveau courrier est déposé dans mon espace candidat).
Donc j'ai fini par faire un script qui à ce jour (14/12/2016) fonctionne très bien pour pouvoir depuis un terminal unix :
- Ouvrir une session sur pôle-emploi.
- Récupérer la liste des courriers déposés dans mon espace candidat au cours des 30 derniers jours.
- Télécharger sur ma machine les PDF des courriers qui ne sont pas déjà présents.
- [macOS uniquement] Leur mettre une étiquette de couleur bleue pour distinguer les nouveaux PDF facilement.

### Environnement nécessaire
- Zsh.
- [Curl](https://curl.haxx.se).
- [oh my zsh](http://ohmyz.sh/) - sans doutes pas impératif, mais il est possible que le script se plaigne de quelque chose si vous ne l'utilisez pas. De toutes façons, vous devriez, voilà, point-barre.
- html-xml-utils (sous macOS avec homebrew : `brew install html-xml-utils`, sous Debian ou Ubuntu `sudo apt-get install html-xml-utils`)

### Utilisation
Le script peut-être utilisé de deux manières différentes :

#### Sans paramètres : mode interactif
`./pe-curl.sh`

Si vous n'avez pas crée de fichier de configuration (voir plus bas) ou bien si le fichier de configuration utilisé ne spécifie pas l'un ou plusieurs des paramètres requis, le script va alors vous demander de préciser, le cas échéant :
- votre identifiant pôle-emploi.
- votre mot de passe.
- votre code postal (ben ouais, va comprendre en quoi c'est impératif pour t'identifier sur le site web).

Puis il téléchargera tous les PDFs **ayant été déposés dans les 30 derniers jours** qu'il trouvera sur votre compte pôle-emploi et qui ne sont pas déjà **dans le repertoire courant (ou dans le répertoire spécifié dans le fichier de configuration)**.

Enfin, il affichera dans le terminal le résumé de ce qui s'est passé.

En bonus, pour ceux qui sont sous macOS, il va générer une notification système, potentiellement envoyer une notification iMessage vers le numéro de votre choix, et même dire à haute voix qu'il a récupéré de nouveaux messages.

#### Avec paramètres
`./pe-curl.sh [--conf fichier-configuration] [--id identifiant] [--pass mot-de-passe] [--zip code-postal] [--pdf-dir repertoire-pdf] [--imsg telephone] [--shut-the-fuck-up]`

Les options suivantes sont disponibles :
- `-- conf` _fichier-configuration_ - permet de préciser l'endroit ou se trouve votre fichier de configuration.
- `--id` _identifiant_ - permet de spécifier votre identifiant pôle-emploi.
- `--pass` _mot-de-passe_ - permet de spécifier votre mot de passe pôle-emploi. **Attention : il n'est pas recommandé de passer votre mot de passe via les options du script. Pour des questions de sécurité, préférez l'utilisation d'un fichier de configuration (voir ci après).**
- `--zip` _code-postal_ - permet de spécifier votre code postal.
- `--pdf-dir` _repertoire-pdf_ - permet de spécifier le répertoire dans lequel chercher et stocker les PDF de pôle-emploi sur votre machine.
- `--imsg` _telephone_ - permet de spécifier votre numéro de téléphone ou tout autre identifiant iMessage pour vous envoyer une notification lorsque de nouveaux courriers ont été téléchargés.
- `--shut-the-fuck-up` - permet de rendre le script silencieux.

Si l'une ou plusieurs des options `--id`, `--pass`, ou `--zip` est manquante le script demandera à l'utilisateur de les saisir avant de continuer.

Si l'option `--pdf-dir` n'est pas spécifiée et que le fichier de configuration ne précise pas le paramètre pdf_directory, le script téléchargera les nouveaux courriers dans le répertoire courant, sous réserve qu'il n'y soient pas déjà.

Si l'un des paramètres fourni dans le fichier de configuration est aussi fourni sous forme d'option lors de l'invocation du script. Les options auront la priorité sur le fichier de configuration.

Un exemple concret d'utilisation du script avec passage de tous les paramètres :
`./pe-curl.sh --conf ./configuration.conf --id 1234567A --pass 123456 --zip 42000 --imsg 0642424242 --pdf-dir ~/Documents/polochon`

### Fichier de configuration
Les deux scripts fournis peuvent utiliser un fichier de configuration.

Par défaut le chemin d'accès au fichier de configuration est './pe.conf', vous pouvez utiliser n'importe quel autre chemin d'accès en le précisant avec l'option --conf.

Exemple de fichier de configuration :

```
identifiant=1234567A
password=123456
zipcode=42000
imessage_address=0642424242
pdf_directory=/Users/mat/Dropbox/_pro/Administratif/_POLE-EMPLOI/
shut_up=true
```

Pour des questions de sécurité, assurez vous que les permissions du fichier de configuration sont adaptées (0600 semble une bonne idée) et que seuls des utilisateurs de confiance y ait accès.

**Remarque :** Dans le fichier de configuration, pour le paramètre `pdf_directory`, ne pas utiliser le ~ pour désigner le répertoire de l'utilisateur courant (aucun problème en revanche pour l'utiliser dans le passage d'options avec `--pdf-dir`). Sans quoi le script applescript utilisé pour attribuer une étiquette de couleur aux nouveau fichiers téléchargés ne fonctionnera pas, et un message d'erreur ressemblant à `165:235: execution error: Impossible de convertir POSIX file "/.:2016123456789.pdf" of application "Finder" en type alias. (-1700)` apparaitra dans la sortie du script pe-curl.sh. Le reste du script continuera de fonctionner comme attendu, au pire vous n'aurez pas l'étiquette de couleur...

### Tâche Cron
Le script peut tout à fait être utilisé pour une tâche Cron, c'est même le but !

Pour éditer la crontab de l'utilisateur actif :
```shell
 crontab -e
```
Ceci devrait ouvir la crontab dans vi (ou un autre éditeur si vous avez spécifié un autre éditeur), passez en mode insertion (touche `i`) puis ajoutez votre tâche Cron.

Appuyez ensuite sur `Esc` puis tapez `:wq` pour sauvegarder, et voilà !

### Remarques
- Le script ne vérifie pas si le login s'est bien passé (pour l'instant en tout cas), donc vérifiez bien que vos informations de connexion sont correctes, sans quoi le script vous dira sempiternellement "Aucun courrier n'a été trouvé".
- Dans le cas ou aucun **nouveau** fichier n'a été téléchargé le script se terminera par "[OK] Aucun nouveau courrier n'a été trouvé"
- Si vous utilisez ce script pour une tâche planifiée Cron, vérifiez que le PATH de votre environnement Cron permette au script de trouver les executables ! Voir le commit [f692f72](https://github.com/daformat/curl-pole-emploi-courriers-candidat/commit/f692f728e7ade219893b4692421118f878b4df8c) ou j'ai du ajouter /usr/local/bin/ au PATH pour que les différents outils de html-xml-utils puissent être lancés depuis la tâche cron.
- Le script test.sh contient une suite de tests basiques permettant de vérifier que tout fonctionne correctement, il peut être utilisé lui aussi avec ou sans options. Les options disponibles pour ce script de test sont `--conf`, `--id`, `--pass`, `--zip` et `--imsg`. Le script de test n'enverra pas de iMessage si tout se passe bien.
