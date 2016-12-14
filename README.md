# Curl Pôle emploi / courriers candidat

## Welcome to pôle emploi!
A zsh script to log-in to pole-emploi from the command-line, and download pdf "courriers" files to the current directory using curl and a few other unix friends.

## Bienvenue à pôle emploi!
J'en avais marre de devoir me taper toutes les étapes de connexion sur pôle-emploi juste pour aller vérifier si j'avais reçu du nouveau courrier (leur système de notification mail n'est vraiment pas fiable et prévient parfois trop tard, voir pas du tout quand un nouveau courrier est déposé dans mon espace candidat).
Donc j'ai fini par faire un script qui à ce jour (14/12/2016) fonctionne très bien pour pouvoir depuis un terminal unix :
- Ouvrir une session sur pôle-emploi.
- Récupérer la liste des courriers déposés dans mon espace candidat au cours des 30 derniers jours.
- Télécharger sur ma machine les PDF des courriers qui ne sont pas déjà présents.

### Environnement nécessaire
- Zsh.
- [Curl](https://curl.haxx.se).
- [oh my zsh](http://ohmyz.sh/) - sans doutes pas impératif, mais il est possible que le script se plaigne de quelque chose si vous ne l'utilisez pas. De toutes façons, vous devriez, voilà, point-barre.
- html-xml-utils (sous macOS avec homebrew : `brew install html-xml-utils`, sous Debian ou Ubuntu `sudo apt-get install html-xml-utils`)

### Utilisation
Le script peut-être utilisé de deux manières différentes :

#### Sans paramètres : mode interactif
Le script va alors vous demander :
- votre identifiant pôle-emploi.
- votre mot de passe.
- votre code postal (ben ouais, va comprendre en quoi c'est imperatif pour t'identifiant sur le site web).

Puis il téléchargera tous les PDFs **ayant été déposés dans les 30 derniers jours** qu'il trouvera sur votre compte et qui ne sont pas déjà **dans le repertoire courant**.

#### Avec paramètres
```shell
  ./pe-curl.sh [--id identifiant] [--pass mot-de-passe] [--zip code-postal] [--pdf-dir repertoire-pdf] [--imsg telephone]
```
Les options suivantes sont disponibles :
- `--id` _identifiant_ - permet de spécifier votre identifiant pôle-emploi.
- `--pass` _mot-de-pass_ - permet de spécifier votre mot de passe pôle-emploi.
- `--zip` _code-postal_ - permet de spécifier votre code postal.
- `--pdf-dir` _repertoire-pdf_ - permet de spécifier le répertoire dans lequel chercher et stocker les PDF de pôle-emploi sur votre machine.
- `--imsg` _telephone_ - permet de spécifier votre numéro de téléphone ou tout autre identifiant iMessage pour vous envoyer une notification lorsque de nouveaux courriers ont été téléchargés.

Si l'une ou plusieurs des options `--id`, `--pass`, ou `--zip` est manquante le script demandera à l'utilisateur de les saisir avant de continuer.

Si l'option `--pdf-dir` n'est pas spécifiée, le script téléchargera les nouveaux courriers dans le répertoire courant, sous réserve qu'il n'y soient pas déjà.
